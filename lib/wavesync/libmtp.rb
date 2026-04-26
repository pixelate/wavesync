# frozen_string_literal: true
# rbs_inline: enabled

require 'open3'

module Wavesync
  class Libmtp
    class Error < StandardError; end
    class ToolNotInstalled < Error; end
    class DeviceNotFound < Error; end

    INSTALL_HINT = 'Install libmtp with `brew install libmtp`'

    DeviceFile = Data.define(:id, :filename, :size, :parent_id, :storage_id)
    DeviceFolder = Data.define(:folder_id, :name, :parent_id, :storage_id)

    #: () -> bool
    def detected?
      _stdout, _stderr, status = Open3.capture3(self.class.tool_path('mtp-detect'))
      status.success?
    rescue ToolNotInstalled
      false
    end

    #: () -> Array[DeviceFile]
    def files
      parse_files(run!('mtp-files'))
    end

    #: () -> Array[DeviceFolder]
    def folders
      parse_folders(run!('mtp-folders'))
    end

    #: (local_path: String, remote_filename: String, parent_id: Integer, storage_id: Integer) -> void
    def send_file(local_path:, remote_filename:, parent_id:, storage_id:)
      run!('mtp-sendfile', '-p', parent_id.to_s, '-s', format_storage_id(storage_id), local_path, remote_filename)
    end

    #: (name: String, parent_id: Integer, storage_id: Integer) -> Integer
    def create_folder(name:, parent_id:, storage_id:)
      output = run!('mtp-newfolder', name, parent_id.to_s, format_storage_id(storage_id))
      match = output.match(/New folder created with ID:\s*(\d+)/)
      raise Error, "Could not parse folder ID from mtp-newfolder output: #{output.inspect}" unless match

      Integer(match[1])
    end

    #: (id: Integer) -> void
    def delete_file(id:)
      run!('mtp-delfile', '-n', id.to_s)
    end

    #: (id: Integer, local_path: String) -> void
    def get_file(id:, local_path:)
      run!('mtp-getfile', id.to_s, local_path)
    end

    #: (String tool) -> String
    def self.tool_path(tool)
      @tool_paths ||= {} #: Hash[String, String]
      cached = @tool_paths[tool]
      return cached if cached

      stdout, _stderr, status = Open3.capture3('which', tool)
      raise ToolNotInstalled, "#{tool} not found. #{INSTALL_HINT}" unless status.success?

      path = stdout.strip
      raise ToolNotInstalled, "#{tool} not found. #{INSTALL_HINT}" if path.empty?

      @tool_paths[tool] = path
    end

    #: () -> void
    def self.reset_tool_path_cache!
      @tool_paths = {} #: Hash[String, String]
    end

    private

    # rubocop:disable Style/ArgumentsForwarding
    #: (String tool, *String args) -> String
    def run!(tool, *args)
      stdout, stderr, status = Open3.capture3(self.class.tool_path(tool), *args)
      raise Error, "#{tool} failed: #{stderr.strip}" unless status.success?

      stdout
    end
    # rubocop:enable Style/ArgumentsForwarding

    #: (Integer storage_id) -> String
    def format_storage_id(storage_id)
      format('0x%08x', storage_id)
    end

    #: (String output) -> Array[DeviceFile]
    def parse_files(output)
      results = [] #: Array[DeviceFile]
      current_id = nil #: Integer?
      current_filename = nil #: String?
      current_size = nil #: Integer?
      current_parent_id = nil #: Integer?
      current_storage_id = nil #: Integer?
      output.each_line do |line|
        case line
        when /^File ID:\s*(\d+)/
          if current_id
            results << DeviceFile.new(id: current_id, filename: current_filename.to_s,
                                      size: current_size || 0, parent_id: current_parent_id || 0,
                                      storage_id: current_storage_id || 0)
          end
          current_id = Integer(Regexp.last_match(1))
          current_filename = nil
          current_size = nil
          current_parent_id = nil
          current_storage_id = nil
        when /^\s+Filename:\s*(.+?)\s*$/
          current_filename = Regexp.last_match(1).to_s
        when /^\s+File size\s+(\d+)/
          current_size = Integer(Regexp.last_match(1))
        when /^\s+Parent ID:\s*(\d+)/
          current_parent_id = Integer(Regexp.last_match(1))
        when /^\s+Storage ID:\s*0x([0-9a-fA-F]+)/
          current_storage_id = Regexp.last_match(1).to_s.hex
        end
      end
      if current_id
        results << DeviceFile.new(id: current_id, filename: current_filename.to_s,
                                  size: current_size || 0, parent_id: current_parent_id || 0,
                                  storage_id: current_storage_id || 0)
      end
      results
    end

    #: (String output) -> Array[DeviceFolder]
    def parse_folders(output)
      results = [] #: Array[DeviceFolder]
      stack = [] #: Array[[Integer, Integer]]
      current_storage = 0 #: Integer
      output.each_line do |line|
        storage_match = line.match(/^Storage(?:\s+ID)?:\s*0x([0-9a-fA-F]+)/i)
        if storage_match
          current_storage = storage_match[1].to_s.hex
          stack.clear
          next
        end

        entry_match = line.match(/^(\s*)(\d+)\s+(\S.*?)\s*$/)
        next unless entry_match

        depth = entry_match[1].to_s.length / 2
        folder_id = Integer(entry_match[2].to_s)
        name = entry_match[3].to_s

        stack.pop while (top = stack.last) && top[0] >= depth
        last = stack.last
        parent_id = last ? last[1] : 0

        results << DeviceFolder.new(folder_id: folder_id, name: name, parent_id: parent_id, storage_id: current_storage)
        stack << [depth, folder_id]
      end
      results
    end
  end
end
