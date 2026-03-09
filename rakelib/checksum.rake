# frozen_string_literal: true

namespace :checksum do
  # Compute the expected checksum for a .work file based on its type.
  #
  # bank*.work  — (sum of all bytes except last) - 1, mod 256
  # arr*.work   — XOR of all bytes from offset 12 to second-to-last
  # markers.work — (sum of bytes from offset 16 to second-to-last) - 1, mod 256
  # project.work — no checksum (plain text)
  #
  # Returns nil for files with no checksum.
  def expected_checksum(file_path, data)
    basename = File.basename(file_path)
    payload = data.byteslice(0, data.bytesize - 1)

    case basename
    when /\Abank\d+\.work\z/
      (payload.bytes.sum - 1) % 256
    when /\Aarr\d+\.work\z/
      payload.bytes[12..].reduce(0, :^)
    when 'markers.work'
      (payload.bytes[16..].sum - 1) % 256
    end
  end

  desc 'Hex-dump a .work file and show the checksum byte location'
  task :dump, [:file] do |_task, args|
    file_path = args[:file]
    abort 'Usage: rake checksum:dump[file.work]' unless file_path
    abort "File not found: #{file_path}" unless File.exist?(file_path)

    data = File.binread(file_path)
    file_size = data.bytesize
    stored_checksum = data.getbyte(file_size - 1)
    computed = expected_checksum(file_path, data)

    puts "File: #{file_path}"
    puts "Size: #{file_size} bytes (0x#{file_size.to_s(16).upcase})"
    if computed
      match = stored_checksum == computed ? 'OK' : 'MISMATCH'
      puts "Last byte (checksum): 0x#{stored_checksum.to_s(16).rjust(2, '0').upcase}  computed: 0x#{computed.to_s(16).rjust(2, '0').upcase}  #{match}"
    else
      puts "Last byte: 0x#{stored_checksum.to_s(16).rjust(2, '0').upcase} (no checksum for this file type)"
    end
    puts

    puts 'Header (first 32 bytes):'
    0.step([32, file_size].min - 1, 16) do |offset|
      row = data.byteslice(offset, 16) || ''
      hex = row.bytes.map { |byte| byte.to_s(16).rjust(2, '0') }.join(' ')
      ascii = row.bytes.map { |byte| byte.between?(0x20, 0x7e) ? byte.chr : '.' }.join
      puts "  #{offset.to_s(16).rjust(8, '0')}: #{hex.ljust(47)}  #{ascii}"
    end
    puts

    tail_start = [file_size - 32, 0].max
    puts 'Tail (last 32 bytes, checksum is the final byte):'
    tail_start.step(file_size - 1, 16) do |offset|
      row = data.byteslice(offset, 16) || ''
      hex = row.bytes.each_with_index.map do |byte, index|
        offset + index == file_size - 1 ? "[#{byte.to_s(16).rjust(2, '0')}]" : byte.to_s(16).rjust(2, '0')
      end.join(' ')
      ascii = row.bytes.map { |byte| byte.between?(0x20, 0x7e) ? byte.chr : '.' }.join
      puts "  #{offset.to_s(16).rjust(8, '0')}: #{hex.ljust(53)}  #{ascii}"
    end
  end

  desc 'Try common checksum algorithms and show which matches the stored value'
  task :brute, [:file] do |_task, args|
    file_path = args[:file]
    abort 'Usage: rake checksum:brute[file.work]' unless file_path
    abort "File not found: #{file_path}" unless File.exist?(file_path)

    data = File.binread(file_path)
    stored_checksum = data.getbyte(data.bytesize - 1)
    payload = data.byteslice(0, data.bytesize - 1).bytes

    puts "File:             #{file_path}"
    puts "Stored checksum:  0x#{stored_checksum.to_s(16).rjust(2, '0').upcase} (#{stored_checksum})"
    puts "Payload size:     #{payload.size} bytes"
    puts

    byte_sum = payload.sum

    candidates = {
      'sum % 256' => byte_sum % 256,
      '(sum - 1) % 256' => (byte_sum - 1) % 256,
      '(sum + 1) % 256' => (byte_sum + 1) % 256,
      '(256 - sum % 256) % 256' => (256 - (byte_sum % 256)) % 256,
      '(-sum) % 256' => (-byte_sum) % 256,
      'XOR of all bytes' => payload.reduce(0, :^),
      'XOR ^ 0xFF' => payload.reduce(0, :^) ^ 0xFF
    }

    [12, 16, 20].each do |offset|
      next unless payload.size > offset

      slice = payload[offset..]
      candidates["offset #{offset}: (sum-1) % 256"] = (slice.sum - 1) % 256
      candidates["offset #{offset}: sum % 256"]       = slice.sum % 256
      candidates["offset #{offset}: XOR"]             = slice.reduce(0, :^)
    end

    matches, misses = candidates.partition { |_, computed| computed == stored_checksum }

    if matches.any?
      puts '=== MATCHES ==='
      matches.each { |label, computed| puts "  MATCH  #{label.ljust(45)} => 0x#{computed.to_s(16).rjust(2, '0').upcase}" }
    else
      puts '=== NO MATCHES ==='
    end
    puts

    puts '=== ALL RESULTS ==='
    (matches + misses).each do |label, computed|
      prefix = computed == stored_checksum ? '  MATCH' : '  miss '
      puts "#{prefix}  #{label.ljust(45)} => 0x#{computed.to_s(16).rjust(2, '0').upcase}"
    end
  end

  desc 'Compare expected vs actual checksum for every .work file in a project dir'
  task :compare, [:dir] do |_task, args|
    dir = args[:dir]
    abort 'Usage: rake checksum:compare[dir]' unless dir
    abort "Directory not found: #{dir}" unless Dir.exist?(dir)

    work_files = Dir[File.join(dir, '*.work')]
    abort "No .work files found in #{dir}" if work_files.empty?

    puts 'File                               Stored   Expected Match?'
    puts '-' * 65

    work_files.each do |file_path|
      data = File.binread(file_path)
      stored = data.getbyte(data.bytesize - 1)
      computed = expected_checksum(file_path, data)

      stored_hex = format('0x%<value>02X', value: stored)
      if computed.nil?
        puts format('%<file>-30s %<stored>10s %<expected>10s %<match>s',
                    file: File.basename(file_path), stored: stored_hex, expected: 'n/a', match: '(no checksum)')
      else
        computed_hex = format('0x%<value>02X', value: computed)
        match = stored == computed ? 'OK' : 'MISMATCH'
        puts format('%<file>-30s %<stored>10s %<expected>10s %<match>s',
                    file: File.basename(file_path), stored: stored_hex, expected: computed_hex, match: match)
      end
    end
  end

  desc 'Verify all .work files in a project dir pass their checksums'
  task :verify, [:dir] do |_task, args|
    dir = args[:dir]
    abort 'Usage: rake checksum:verify[dir]' unless dir
    abort "Directory not found: #{dir}" unless Dir.exist?(dir)

    work_files = Dir[File.join(dir, '*.work')]
    abort "No .work files found in #{dir}" if work_files.empty?

    all_ok = true
    work_files.each do |file_path|
      data = File.binread(file_path)
      stored = data.getbyte(data.bytesize - 1)
      computed = expected_checksum(file_path, data)

      next if computed.nil?

      if stored == computed
        puts "OK        #{File.basename(file_path)}"
      else
        puts "MISMATCH  #{File.basename(file_path)}  stored=0x#{stored.to_s(16).rjust(2, '0').upcase} expected=0x#{computed.to_s(16).rjust(2, '0').upcase}"
        all_ok = false
      end
    end

    exit 1 unless all_ok
  end
end
