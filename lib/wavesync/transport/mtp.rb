# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require_relative '../libmtp'

module Wavesync
  module Transport
    class Mtp
      DEFAULT_CACHE_ROOT = File.join(Dir.home, '.cache', 'wavesync').freeze

      attr_reader :working_directory #: String
      attr_reader :device_path #: String
      attr_reader :name #: String

      #: ({ name: String, model: String, path: String, transport: String? } device_config, ?libmtp: Libmtp, ?cache_root: String) -> void
      def initialize(device_config, libmtp: Libmtp.new, cache_root: DEFAULT_CACHE_ROOT)
        @name = device_config[:name]
        @device_path = device_config[:path]
        @libmtp = libmtp
        @working_directory = File.join(cache_root, sanitize_dir_name(@name))
        FileUtils.mkdir_p(@working_directory)
      end

      #: () ?{ (Integer, Integer, String) -> void } -> void
      def prepare!(&progress)
        device_files = @libmtp.files
        folder_paths = build_folder_paths(@libmtp.folders)

        candidates = device_files.filter_map do |device_file|
          relative_path = relative_path_for(device_file, folder_paths)
          next unless relative_path
          next unless wav?(device_file.filename)

          local_path = File.join(@working_directory, relative_path)
          next if File.exist?(local_path) && File.size(local_path) == device_file.size

          { device_file: device_file, relative_path: relative_path, local_path: local_path }
        end

        candidates.each_with_index do |candidate, index|
          progress&.call(index, candidates.size, candidate[:relative_path])
          FileUtils.mkdir_p(File.dirname(candidate[:local_path]))
          @libmtp.get_file(id: candidate[:device_file].id, local_path: candidate[:local_path])
        end
      end

      #: () ?{ (Integer, Integer, String) -> void } -> void
      def commit!(&progress)
        files_by_parent = @libmtp.files.group_by(&:parent_id)
        folders_by_parent = @libmtp.folders.group_by(&:parent_id)
        storage_id = primary_storage_id(folders_by_parent)

        local_files = enumerate_local_files
        local_files.each_with_index do |entry, index|
          progress&.call(index, local_files.size, entry[:relative_path])
          push_one(entry, files_by_parent: files_by_parent, folders_by_parent: folders_by_parent, storage_id: storage_id)
        end
      end

      private

      #: () -> Array[{ local_path: String, relative_path: String, remote_path: String }]
      def enumerate_local_files
        Dir.glob(File.join(@working_directory, '**', '*'))
           .reject { |path| File.directory?(path) }
           .sort
           .map do |local_path|
             relative_path = local_path.sub(%r{\A#{Regexp.escape(@working_directory)}/?}, '')
             remote_path = join_remote_paths(@device_path, relative_path)
             { local_path: local_path, relative_path: relative_path, remote_path: remote_path }
           end
      end

      #: ({ local_path: String, relative_path: String, remote_path: String } entry, files_by_parent: Hash[Integer, Array[Libmtp::DeviceFile]], folders_by_parent: Hash[Integer, Array[Libmtp::DeviceFolder]], storage_id: Integer) -> void
      def push_one(entry, files_by_parent:, folders_by_parent:, storage_id:)
        target_dir = File.dirname(entry[:remote_path])
        parent_id = ensure_folder(target_dir, folders_by_parent: folders_by_parent, storage_id: storage_id)

        filename = File.basename(entry[:remote_path])
        existing = (files_by_parent[parent_id] || []).find { |file| file.filename == filename }

        if existing
          return if existing.size == File.size(entry[:local_path])

          @libmtp.delete_file(id: existing.id)
          files_by_parent[parent_id]&.delete(existing)
        end

        @libmtp.send_file(
          local_path: entry[:local_path],
          remote_filename: filename,
          parent_id: parent_id,
          storage_id: storage_id
        )
      end

      #: (String remote_path, folders_by_parent: Hash[Integer, Array[Libmtp::DeviceFolder]], storage_id: Integer) -> Integer
      def ensure_folder(remote_path, folders_by_parent:, storage_id:)
        parent_id = 0
        path_components(remote_path).each do |name|
          children = folders_by_parent[parent_id] || []
          existing = children.find { |folder| folder.name == name }
          if existing
            parent_id = existing.folder_id
          else
            new_id = @libmtp.create_folder(name: name, parent_id: parent_id, storage_id: storage_id)
            new_folder = Libmtp::DeviceFolder.new(folder_id: new_id, name: name, parent_id: parent_id, storage_id: storage_id)
            (folders_by_parent[parent_id] ||= []) << new_folder
            parent_id = new_id
          end
        end
        parent_id
      end

      #: (Hash[Integer, Array[Libmtp::DeviceFolder]] folders_by_parent) -> Integer
      def primary_storage_id(folders_by_parent)
        first_storage = folders_by_parent.values.flatten.map(&:storage_id).compact.first
        raise Libmtp::DeviceNotFound, 'No MTP device detected. Connect the device and unmount it from any other app.' unless first_storage

        first_storage
      end

      #: (String path) -> Array[String]
      def path_components(path)
        path.split('/').reject { |component| component.empty? || component == '.' }
      end

      #: (String left, String right) -> String
      def join_remote_paths(left, right)
        "#{left}/#{right}".split('/').reject(&:empty?).join('/')
      end

      #: (String name) -> String
      def sanitize_dir_name(name)
        sanitized = name.downcase.gsub(/[^a-z0-9._-]/, '_')
        sanitized.empty? ? 'device' : sanitized
      end

      #: (Array[Libmtp::DeviceFolder] folders) -> Hash[Integer, String]
      def build_folder_paths(folders)
        by_id = {} #: Hash[Integer, Libmtp::DeviceFolder]
        folders.each { |folder| by_id[folder.folder_id] = folder }
        paths = { 0 => '' } #: Hash[Integer, String]
        folders.each { |folder| resolve_folder_path(folder.folder_id, by_id, paths) }
        paths
      end

      #: (Integer folder_id, Hash[Integer, Libmtp::DeviceFolder] by_id, Hash[Integer, String] paths) -> String?
      def resolve_folder_path(folder_id, by_id, paths)
        return paths[folder_id] if paths.key?(folder_id)

        folder = by_id[folder_id]
        return nil unless folder

        parent_path = resolve_folder_path(folder.parent_id, by_id, paths) || ''
        full_path = parent_path.empty? ? folder.name : "#{parent_path}/#{folder.name}"
        paths[folder_id] = full_path
        full_path
      end

      #: (Libmtp::DeviceFile device_file, Hash[Integer, String] folder_paths) -> String?
      def relative_path_for(device_file, folder_paths)
        folder_path = folder_paths[device_file.parent_id]
        return nil unless folder_path

        full_path = folder_path.empty? ? device_file.filename : "#{folder_path}/#{device_file.filename}"
        device_root = path_components(@device_path).join('/')
        return full_path if device_root.empty?
        return full_path[(device_root.length + 1)..] if full_path.start_with?("#{device_root}/")

        nil
      end

      #: (String filename) -> bool
      def wav?(filename)
        File.extname(filename).downcase == '.wav'
      end
    end
  end
end
