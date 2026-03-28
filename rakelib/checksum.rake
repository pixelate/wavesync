namespace :checksum do
  # Compute the expected checksum for a .work file based on its type.
  #
  # bank*.work   — u16 wrapping sum of bytes from offset 16 to third-to-last (big-endian, last 2 bytes)
  # arr*.work    — XOR of all bytes from offset 12 to second-to-last (last byte)
  # markers.work — u16 wrapping sum of bytes from offset 16 to third-to-last (big-endian, last 2 bytes)
  # project.work — no checksum (plain text)
  #
  # Returns nil for files with no checksum.
  def expected_checksum(file_path, data)
    basename = File.basename(file_path)

    case basename
    when /\Abank\d+\.work\z/
      data.byteslice(16, data.bytesize - 18).bytes.reduce(0) { |acc, byte| (acc + byte) & 0xFFFF }
    when /\Aarr\d+\.work\z/
      data.byteslice(12, data.bytesize - 13).bytes.reduce(0, :^)
    when "markers.work"
      data.byteslice(16, data.bytesize - 18).bytes.reduce(0) { |acc, byte| (acc + byte) & 0xFFFF }
    end
  end

  # Returns the number of bytes used by the checksum field for a given file.
  def checksum_width(file_path)
    basename = File.basename(file_path)
    case basename
    when /\Abank\d+\.work\z/, "markers.work" then 2
    when /\Aarr\d+\.work\z/ then 1
    end
  end

  # Read the stored checksum integer from the last checksum_width bytes of data.
  def stored_checksum(file_path, data)
    width = checksum_width(file_path)
    return nil unless width

    file_size = data.bytesize
    if width == 2
      (data.getbyte(file_size - 2) << 8) | data.getbyte(file_size - 1)
    else
      data.getbyte(file_size - 1)
    end
  end

  desc "Hex-dump a .work file and show the checksum byte location"
  task :dump, [:file] do |_task, args|
    file_path = args[:file]
    abort "Usage: rake checksum:dump[file.work]" unless file_path
    abort "File not found: #{file_path}" unless File.exist?(file_path)

    data = File.binread(file_path)
    file_size = data.bytesize
    chk_stored = stored_checksum(file_path, data)
    computed = expected_checksum(file_path, data)
    width = checksum_width(file_path)

    puts "File: #{file_path}"
    puts "Size: #{file_size} bytes (0x#{file_size.to_s(16).upcase})"
    if computed
      match = chk_stored == computed ? "OK" : "MISMATCH"
      hex_width = width == 2 ? 4 : 2
      puts "Last #{width} byte(s) (checksum): 0x#{chk_stored.to_s(16).rjust(hex_width, '0').upcase}  computed: 0x#{computed.to_s(16).rjust(hex_width, '0').upcase}  #{match}"
    else
      puts "Last byte: 0x#{data.getbyte(file_size - 1).to_s(16).rjust(2, '0').upcase} (no checksum for this file type)"
    end
    puts

    puts "Header (first 32 bytes):"
    0.step([32, file_size].min - 1, 16) do |offset|
      row = data.byteslice(offset, 16) || ""
      hex = row.bytes.map { |byte| byte.to_s(16).rjust(2, "0") }.join(" ")
      ascii = row.bytes.map { |byte| byte.between?(0x20, 0x7e) ? byte.chr : "." }.join
      puts "  #{offset.to_s(16).rjust(8, '0')}: #{hex.ljust(47)}  #{ascii}"
    end
    puts

    chk_start = file_size - (width || 1)
    tail_start = [file_size - 32, 0].max
    puts "Tail (last 32 bytes, checksum is the final #{width || 1} byte(s)):"
    tail_start.step(file_size - 1, 16) do |offset|
      row = data.byteslice(offset, 16) || ""
      hex = row.bytes.each_with_index.map do |byte, index|
        (offset + index >= chk_start) ? "[#{byte.to_s(16).rjust(2, '0')}]" : byte.to_s(16).rjust(2, "0")
      end.join(" ")
      ascii = row.bytes.map { |byte| byte.between?(0x20, 0x7e) ? byte.chr : "." }.join
      puts "  #{offset.to_s(16).rjust(8, '0')}: #{hex.ljust(53)}  #{ascii}"
    end
  end

  desc "Try common checksum algorithms and show which matches the stored value"
  task :brute, [:file] do |_task, args|
    file_path = args[:file]
    abort "Usage: rake checksum:brute[file.work]" unless file_path
    abort "File not found: #{file_path}" unless File.exist?(file_path)

    data = File.binread(file_path)
    chk_stored = stored_checksum(file_path, data)
    payload_u8 = data.byteslice(0, data.bytesize - 1).bytes
    payload_u16 = data.byteslice(0, data.bytesize - 2).bytes

    puts "File:             #{file_path}"
    puts "Stored checksum:  0x#{chk_stored.to_s(16).rjust(4, '0').upcase} (#{chk_stored})"
    puts "Payload size:     #{data.bytesize} bytes"
    puts

    byte_sum = payload_u8.sum

    candidates = {
      "u8: sum % 256"               => byte_sum % 256,
      "u8: (sum - 1) % 256"         => (byte_sum - 1) % 256,
      "u8: (sum + 1) % 256"         => (byte_sum + 1) % 256,
      "u8: (256 - sum % 256) % 256" => (256 - byte_sum % 256) % 256,
      "u8: (-sum) % 256"            => (-byte_sum) % 256,
      "u8: XOR of all bytes"        => payload_u8.reduce(0, :^),
      "u8: XOR ^ 0xFF"              => payload_u8.reduce(0, :^) ^ 0xFF,
      "u16: wrapping sum"           => payload_u16.reduce(0) { |acc, byte| (acc + byte) & 0xFFFF },
    }

    [12, 16, 20].each do |offset|
      next unless payload_u8.size > offset
      slice_u8 = payload_u8[offset..]
      slice_u16 = payload_u16[offset..]
      candidates["u8 offset #{offset}: (sum-1) % 256"] = (slice_u8.sum - 1) % 256
      candidates["u8 offset #{offset}: sum % 256"]      = slice_u8.sum % 256
      candidates["u8 offset #{offset}: XOR"]            = slice_u8.reduce(0, :^)
      candidates["u16 offset #{offset}: wrapping sum"]  = slice_u16.reduce(0) { |acc, byte| (acc + byte) & 0xFFFF }
    end

    matches, misses = candidates.partition { |_, computed| computed == chk_stored }

    if matches.any?
      puts "=== MATCHES ==="
      matches.each { |label, computed| puts "  MATCH  #{label.ljust(45)} => 0x#{computed.to_s(16).rjust(4, '0').upcase}" }
      puts
    else
      puts "=== NO MATCHES ==="
      puts
    end

    puts "=== ALL RESULTS ==="
    (matches + misses).each do |label, computed|
      prefix = computed == chk_stored ? "  MATCH" : "  miss "
      puts "#{prefix}  #{label.ljust(45)} => 0x#{computed.to_s(16).rjust(4, '0').upcase}"
    end
  end

  desc "Compare expected vs actual checksum for every .work file in a project dir"
  task :compare, [:dir] do |_task, args|
    dir = args[:dir]
    abort "Usage: rake checksum:compare[dir]" unless dir
    abort "Directory not found: #{dir}" unless Dir.exist?(dir)

    work_files = Dir[File.join(dir, "*.work")].sort
    abort "No .work files found in #{dir}" if work_files.empty?

    puts "%-30s %10s %10s %s" % ["File", "Stored", "Expected", "Match?"]
    puts "-" * 65

    work_files.each do |file_path|
      data = File.binread(file_path)
      chk_stored = stored_checksum(file_path, data)
      computed = expected_checksum(file_path, data)

      if computed.nil?
        puts "%-30s %10s %10s %s" % [File.basename(file_path), "0x%04X" % data.getbyte(data.bytesize - 1), "n/a", "(no checksum)"]
      else
        match = chk_stored == computed ? "OK" : "MISMATCH"
        puts "%-30s %10s %10s %s" % [File.basename(file_path), "0x%04X" % chk_stored, "0x%04X" % computed, match]
      end
    end
  end

  desc "Verify all .work files in a project dir pass their checksums"
  task :verify, [:dir] do |_task, args|
    dir = args[:dir]
    abort "Usage: rake checksum:verify[dir]" unless dir
    abort "Directory not found: #{dir}" unless Dir.exist?(dir)

    work_files = Dir[File.join(dir, "*.work")].sort
    abort "No .work files found in #{dir}" if work_files.empty?

    all_ok = true
    work_files.each do |file_path|
      data = File.binread(file_path)
      chk_stored = stored_checksum(file_path, data)
      computed = expected_checksum(file_path, data)

      next if computed.nil?

      if chk_stored == computed
        puts "OK        #{File.basename(file_path)}"
      else
        puts "MISMATCH  #{File.basename(file_path)}  stored=0x#{chk_stored.to_s(16).rjust(4, '0').upcase} expected=0x#{computed.to_s(16).rjust(4, '0').upcase}"
        all_ok = false
      end
    end

    exit 1 unless all_ok
  end
end
