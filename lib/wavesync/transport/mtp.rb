# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../libmtp'
require_relative '../cue_chunk'
require_relative '../logger'

module Wavesync
  module Transport
    class Mtp
      DEFAULT_CACHE_ROOT = File.join(Dir.home, '.cache', 'wavesync').freeze
      MTP_ILLEGAL_CHARACTERS = %r{[<>:"/\\|?*\x00-\x1f]} #: Regexp
      CACHE_DIR_ILLEGAL_CHARACTERS = /[^a-z0-9._-]/ #: Regexp
      MANIFEST_FILENAME = '.manifest.yml'

      attr_reader :working_directory #: String
      attr_reader :device_path #: String
      attr_reader :name #: String

      #: (String name, ?cache_root: String) -> String
      def self.cache_path(name, cache_root: DEFAULT_CACHE_ROOT)
        File.join(cache_root, sanitize_dir_name(name))
      end

      #: (String name) -> String
      def self.sanitize_dir_name(name)
        sanitized = name.downcase.gsub(CACHE_DIR_ILLEGAL_CHARACTERS, '_')
        sanitized.empty? ? 'device' : sanitized
      end

      #: ({ name: String, model: String, path: String, transport: String?, mp3_bitrate: Integer } device_config, ?libmtp: Libmtp, ?cache_root: String) -> void
      def initialize(device_config, libmtp: Libmtp.new, cache_root: DEFAULT_CACHE_ROOT)
        @name = device_config[:name]
        @device_path = device_config[:path]
        @libmtp = libmtp
        @working_directory = self.class.cache_path(@name, cache_root: cache_root)
        FileUtils.mkdir_p(@working_directory)
      end

      #: (?stop_when: ^() -> bool) ?{ (Integer, Integer, String) -> void } -> void
      def prepare!(stop_when: nil, &progress)
        device_files = @libmtp.files
        folder_paths = build_folder_paths(@libmtp.folders)

        candidates = device_files.filter_map do |device_file|
          next unless wav?(device_file.filename)

          relative_path = relative_path_for(device_file, folder_paths)
          next unless relative_path

          local_path = File.join(@working_directory, relative_path)
          { device_file: device_file, relative_path: relative_path, local_path: local_path }
        end

        Dir.mktmpdir('wavesync_mtp_pull') do |tmpdir|
          candidates.each_with_index do |candidate, index|
            break if stop_when&.call

            progress&.call(index, candidates.size, candidate[:relative_path])
            pull_if_cues_differ(candidate, tmpdir)
          end
        end
      end

      #: () -> void
      def begin_push!
        @push_files_by_parent = @libmtp.files.group_by(&:parent_id)
        @push_folders_by_parent = @libmtp.folders.group_by(&:parent_id)
        @push_storage_id = primary_storage_id(@push_folders_by_parent)
        @push_manifest = load_manifest
      end

      #: (String relative_path) -> void
      def push_file!(relative_path)
        files_by_parent = @push_files_by_parent
        folders_by_parent = @push_folders_by_parent
        storage_id = @push_storage_id
        raise Libmtp::Error, 'push_file! called before begin_push!' unless files_by_parent && folders_by_parent && storage_id

        local_path = File.join(@working_directory, relative_path)
        return unless File.file?(local_path)

        remote_path = join_remote_paths(@device_path, relative_path)
        entry = { local_path: local_path, relative_path: relative_path, remote_path: remote_path } #: { local_path: String, relative_path: String, remote_path: String }
        push_one(entry, files_by_parent: files_by_parent, folders_by_parent: folders_by_parent, storage_id: storage_id)
      end

      #: () -> void
      def finish_push!
        save_manifest if @push_manifest
        @push_files_by_parent = nil
        @push_folders_by_parent = nil
        @push_storage_id = nil
        @push_manifest = nil
        @libmtp.close!
      end

      #: () ?{ (Integer, Integer, String) -> void } -> void
      def commit!(&progress)
        begin_push!
        local_files = enumerate_local_files
        local_files.each_with_index do |entry, index|
          progress&.call(index, local_files.size, entry[:relative_path])
          push_file!(entry[:relative_path])
        end
        finish_push!
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

        filename = sanitize_for_mtp(File.basename(entry[:remote_path]))
        existing = (files_by_parent[parent_id] || []).find { |file| sanitize_for_mtp(file.filename) == filename }

        local_size = File.size(entry[:local_path])
        manifest = @push_manifest || {} #: Hash[String, Integer]
        manifest_size = manifest[entry[:relative_path]]

        if existing && (manifest_size == local_size || (manifest_size.nil? && existing.size == local_size))
          manifest[entry[:relative_path]] = local_size
          return
        end

        if existing
          Logger.log_event("MTP replacing (size mismatch device=#{existing.size} local=#{local_size}): #{entry[:relative_path]}")
          @libmtp.delete_file(id: existing.id)
          files_by_parent[parent_id]&.delete(existing)
        else
          Logger.log_event("MTP uploading new file (#{local_size} bytes): #{entry[:relative_path]}")
        end

        @libmtp.send_file(
          local_path: entry[:local_path],
          remote_filename: filename,
          parent_id: parent_id,
          storage_id: storage_id
        )
        manifest[entry[:relative_path]] = local_size
      end

      #: (String remote_path, folders_by_parent: Hash[Integer, Array[Libmtp::DeviceFolder]], storage_id: Integer) -> Integer
      def ensure_folder(remote_path, folders_by_parent:, storage_id:)
        parent_id = 0
        path_components(remote_path).each do |raw_name|
          name = sanitize_for_mtp(raw_name)
          children = folders_by_parent[parent_id] || []
          existing = children.find { |folder| sanitize_for_mtp(folder.name) == name }
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

      #: (String name) -> String
      def normalize_unicode(name)
        name.unicode_normalize(:nfc)
      end

      #: () -> String
      def manifest_path
        File.join(@working_directory, MANIFEST_FILENAME)
      end

      #: () -> Hash[String, Integer]
      def load_manifest
        return {} unless File.exist?(manifest_path)

        data = YAML.safe_load_file(manifest_path)
        data.is_a?(Hash) ? data : {}
      rescue Psych::SyntaxError
        {}
      end

      #: () -> void
      def save_manifest
        manifest = @push_manifest
        return unless manifest

        File.write(manifest_path, manifest.to_yaml)
      end

      #: (String name) -> String
      def sanitize_for_mtp(name)
        normalize_unicode(name).gsub(MTP_ILLEGAL_CHARACTERS, '')
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

      #: ({ device_file: Libmtp::DeviceFile, relative_path: String, local_path: String } candidate, String tmpdir) -> void
      def pull_if_cues_differ(candidate, tmpdir)
        device_file = candidate[:device_file]
        local_path = candidate[:local_path]
        tmp_path = File.join(tmpdir, "#{device_file.id}.wav")

        begin
          @libmtp.get_file(id: device_file.id, local_path: tmp_path)

          device_cues = CueChunk.read(tmp_path)
          local_cues = File.exist?(local_path) ? CueChunk.read(local_path) : [] #: Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}]
          return if CueChunk.same?(device_cues, local_cues)

          FileUtils.mkdir_p(File.dirname(local_path))
          FileUtils.mv(tmp_path, local_path)
        ensure
          FileUtils.rm_f(tmp_path)
        end
      end
    end
  end
end
