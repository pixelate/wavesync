# frozen_string_literal: true

require 'ffi'

module Wavesync
  class Libmtp
    class Error < StandardError; end
    class DeviceNotFound < Error; end

    INSTALL_HINT = 'Install libmtp with `brew install libmtp`'

    DeviceFile = Data.define(:id, :filename, :size, :parent_id, :storage_id)
    DeviceFolder = Data.define(:folder_id, :name, :parent_id, :storage_id)

    LIBRARY_PATHS = [
      '/usr/local/opt/libmtp/lib/libmtp.dylib',
      '/opt/homebrew/opt/libmtp/lib/libmtp.dylib',
      'libmtp.dylib',
      'libmtp.so.9',
      'libmtp.so'
    ].freeze

    module FFIBindings
      extend FFI::Library

      begin
        ffi_lib LIBRARY_PATHS
      rescue LoadError
        # Library missing; instance methods raise via ensure_loaded! when used.
      end

      LIBMTP_STORAGE_SORTBY_NOTSORTED = 0

      LIBMTP_FILETYPE_WAV     = 1
      LIBMTP_FILETYPE_MP3     = 2
      LIBMTP_FILETYPE_OGG     = 4
      LIBMTP_FILETYPE_AAC     = 30
      LIBMTP_FILETYPE_FLAC    = 32
      LIBMTP_FILETYPE_M4A     = 34
      LIBMTP_FILETYPE_UNKNOWN = 44

      class DeviceEntry < FFI::Struct
        layout :vendor,       :pointer,
               :vendor_id,    :uint16,
               :product,      :pointer,
               :product_id,   :uint16,
               :device_flags, :uint32
      end

      class RawDevice < FFI::Struct
        layout :device_entry, DeviceEntry,
               :bus_location, :uint32,
               :devnum,       :uint8
      end

      class Folder < FFI::Struct
        layout :folder_id,  :uint32,
               :parent_id,  :uint32,
               :storage_id, :uint32,
               :name,       :pointer,
               :sibling,    :pointer,
               :child,      :pointer
      end

      class File < FFI::Struct
        layout :item_id,          :uint32,
               :parent_id,        :uint32,
               :storage_id,       :uint32,
               :filename,         :pointer,
               :filesize,         :uint64,
               :modificationdate, :long,
               :filetype,         :int,
               :next,             :pointer
      end

      class DeviceStorage < FFI::Struct
        layout :id,                    :uint32,
               :storage_type,          :uint16,
               :filesystem_type,       :uint16,
               :access_capability,     :uint16,
               :max_capacity,          :uint64,
               :free_space_in_bytes,   :uint64,
               :free_space_in_objects, :uint64,
               :storage_description,   :pointer,
               :volume_identifier,     :pointer,
               :next,                  :pointer,
               :prev,                  :pointer
      end

      class MtpDevice < FFI::Struct
        layout :object_bitsize, :uint8,
               :params,         :pointer,
               :usbinfo,        :pointer,
               :storage,        :pointer
      end

      def self.bind!
        return if @bound

        attach_function :LIBMTP_Init,                            [],                          :void
        attach_function :LIBMTP_Detect_Raw_Devices,              %i[pointer pointer],         :int
        attach_function :LIBMTP_Open_Raw_Device,                 [:pointer],                  :pointer
        attach_function :LIBMTP_Get_Storage,                     %i[pointer int],             :int
        attach_function :LIBMTP_Get_Folder_List_For_Storage,     %i[pointer uint32],          :pointer
        attach_function :LIBMTP_Get_Filelisting_With_Callback,   %i[pointer pointer pointer], :pointer
        attach_function :LIBMTP_Send_File_From_File,             %i[pointer string pointer pointer pointer], :int
        attach_function :LIBMTP_Create_Folder,                   %i[pointer pointer uint32 uint32], :uint32
        attach_function :LIBMTP_Delete_Object,                   %i[pointer uint32], :int
        attach_function :LIBMTP_Get_File_To_File,                %i[pointer uint32 string pointer pointer], :int
        attach_function :LIBMTP_destroy_folder_t,                [:pointer],                  :void
        attach_function :LIBMTP_destroy_file_t,                  [:pointer],                  :void
        attach_function :LIBMTP_Release_Device,                  [:pointer],                  :void
        attach_function :LIBMTP_FreeMemory,                      [:pointer],                  :void
        attach_function :LIBMTP_Dump_Errorstack,                 [:pointer],                  :void
        attach_function :LIBMTP_Clear_Errorstack,                [:pointer],                  :void
        @bound = true
      end
    end

    @library_initialized = false

    class << self
      #: () -> void
      def init_library!
        return if @library_initialized

        FFIBindings.bind!
        FFIBindings.LIBMTP_Init
        @library_initialized = true
      end
    end

    #: () -> void
    def initialize
      @device_handle = nil #: FFI::Pointer?
      @raw_devices_pointer = nil #: FFI::Pointer?
    end

    #: () -> bool
    def detected?
      ensure_library_loaded!
      raw_devices_pointer_pointer = FFI::MemoryPointer.new(:pointer)
      count_pointer = FFI::MemoryPointer.new(:int)
      result = FFIBindings.LIBMTP_Detect_Raw_Devices(raw_devices_pointer_pointer, count_pointer)
      count = count_pointer.read_int
      raw_devices_address = raw_devices_pointer_pointer.read_pointer
      FFIBindings.LIBMTP_FreeMemory(raw_devices_address) unless raw_devices_address.null?
      result.zero? && count.positive?
    rescue Error
      false
    end

    #: () -> Array[DeviceFile]
    def files
      ensure_open!
      list_head = FFIBindings.LIBMTP_Get_Filelisting_With_Callback(@device_handle, nil, nil)
      result = walk_files(list_head)
      FFIBindings.LIBMTP_destroy_file_t(list_head) unless list_head.null?
      result
    end

    #: () -> Array[DeviceFolder]
    def folders
      ensure_open!
      mtp_device = FFIBindings::MtpDevice.new(@device_handle)
      result = [] #: Array[DeviceFolder]
      storage_node = mtp_device[:storage]
      until storage_node.null?
        storage = FFIBindings::DeviceStorage.new(storage_node)
        storage_id = storage[:id]
        folder_root = FFIBindings.LIBMTP_Get_Folder_List_For_Storage(@device_handle, storage_id)
        walk_folders(folder_root, storage_id, result) unless folder_root.null?
        FFIBindings.LIBMTP_destroy_folder_t(folder_root) unless folder_root.null?
        storage_node = storage[:next]
      end
      result
    end

    #: (local_path: String, remote_filename: String, parent_id: Integer, storage_id: Integer) -> void
    def send_file(local_path:, remote_filename:, parent_id:, storage_id:)
      ensure_open!
      filesize = ::File.size(local_path)
      filename_pointer = FFI::MemoryPointer.from_string(remote_filename)
      file_metadata = FFIBindings::File.new
      file_metadata[:item_id] = 0
      file_metadata[:parent_id] = parent_id
      file_metadata[:storage_id] = storage_id
      file_metadata[:filename] = filename_pointer
      file_metadata[:filesize] = filesize
      file_metadata[:modificationdate] = 0
      file_metadata[:filetype] = filetype_for(remote_filename)
      result = FFIBindings.LIBMTP_Send_File_From_File(@device_handle, local_path, file_metadata.to_ptr, nil, nil)
      raise_on_error!(result, "send_file failed for #{local_path}")
    end

    #: (name: String, parent_id: Integer, storage_id: Integer) -> Integer
    def create_folder(name:, parent_id:, storage_id:)
      ensure_open!
      name_pointer = FFI::MemoryPointer.from_string(name)
      new_id = FFIBindings.LIBMTP_Create_Folder(@device_handle, name_pointer, parent_id, storage_id)
      raise Error, "create_folder failed for #{name.inspect}" if new_id.zero?

      new_id
    end

    #: (id: Integer) -> void
    def delete_file(id:)
      ensure_open!
      result = FFIBindings.LIBMTP_Delete_Object(@device_handle, id)
      raise_on_error!(result, "delete_file failed for id #{id}")
    end

    #: (id: Integer, local_path: String) -> void
    def get_file(id:, local_path:)
      ensure_open!
      result = FFIBindings.LIBMTP_Get_File_To_File(@device_handle, id, local_path, nil, nil)
      raise_on_error!(result, "get_file failed for id #{id}")
    end

    #: () -> void
    def close!
      device_handle = @device_handle
      raw_devices_pointer = @raw_devices_pointer
      FFIBindings.LIBMTP_Release_Device(device_handle) if device_handle
      FFIBindings.LIBMTP_FreeMemory(raw_devices_pointer) if raw_devices_pointer && !raw_devices_pointer.null?
      @device_handle = nil
      @raw_devices_pointer = nil
    end

    private

    #: () -> void
    def ensure_library_loaded!
      self.class.init_library!
    rescue LoadError, FFI::NotFoundError => e
      raise Error, "#{e.message}. #{INSTALL_HINT}"
    end

    #: () -> void
    def ensure_open!
      return if @device_handle

      ensure_library_loaded!
      raw_devices_pointer_pointer = FFI::MemoryPointer.new(:pointer)
      count_pointer = FFI::MemoryPointer.new(:int)
      result = FFIBindings.LIBMTP_Detect_Raw_Devices(raw_devices_pointer_pointer, count_pointer)
      device_count = count_pointer.read_int
      raise DeviceNotFound, 'No MTP device detected. Connect the device and unmount it from any other app.' unless result.zero? && device_count.positive?

      raw_devices_pointer = raw_devices_pointer_pointer.read_pointer
      first_raw_device = FFIBindings::RawDevice.new(raw_devices_pointer)
      device_handle = FFIBindings.LIBMTP_Open_Raw_Device(first_raw_device.to_ptr)
      if device_handle.null?
        FFIBindings.LIBMTP_FreeMemory(raw_devices_pointer)
        raise Error, 'Could not open MTP device'
      end

      FFIBindings.LIBMTP_Clear_Errorstack(device_handle)
      get_storage_result = FFIBindings.LIBMTP_Get_Storage(device_handle, FFIBindings::LIBMTP_STORAGE_SORTBY_NOTSORTED)
      unless get_storage_result.zero?
        FFIBindings.LIBMTP_Dump_Errorstack(device_handle)
        FFIBindings.LIBMTP_Release_Device(device_handle)
        FFIBindings.LIBMTP_FreeMemory(raw_devices_pointer)
        raise Error, 'LIBMTP_Get_Storage failed'
      end

      @device_handle = device_handle
      @raw_devices_pointer = raw_devices_pointer
    end

    #: (FFI::Pointer list_head) -> Array[DeviceFile]
    def walk_files(list_head)
      result = [] #: Array[DeviceFile]
      node = list_head
      until node.null?
        file = FFIBindings::File.new(node)
        filename_pointer = file[:filename]
        filename = filename_pointer.null? ? '' : filename_pointer.read_string.force_encoding(Encoding::UTF_8)
        result << DeviceFile.new(
          id: file[:item_id],
          filename: filename,
          size: file[:filesize],
          parent_id: file[:parent_id],
          storage_id: file[:storage_id]
        )
        node = file[:next]
      end
      result
    end

    #: (FFI::Pointer node, Integer storage_id, Array[DeviceFolder] accumulator) -> void
    def walk_folders(node, storage_id, accumulator)
      return if node.null?

      folder = FFIBindings::Folder.new(node)
      name_pointer = folder[:name]
      name = name_pointer.null? ? '' : name_pointer.read_string.force_encoding(Encoding::UTF_8)
      accumulator << DeviceFolder.new(
        folder_id: folder[:folder_id],
        name: name,
        parent_id: folder[:parent_id],
        storage_id: storage_id
      )
      walk_folders(folder[:child], storage_id, accumulator)
      walk_folders(folder[:sibling], storage_id, accumulator)
    end

    #: (String filename) -> Integer
    def filetype_for(filename)
      case ::File.extname(filename).downcase
      when '.wav' then FFIBindings::LIBMTP_FILETYPE_WAV
      when '.mp3' then FFIBindings::LIBMTP_FILETYPE_MP3
      when '.flac' then FFIBindings::LIBMTP_FILETYPE_FLAC
      when '.m4a' then FFIBindings::LIBMTP_FILETYPE_M4A
      when '.aac' then FFIBindings::LIBMTP_FILETYPE_AAC
      when '.ogg' then FFIBindings::LIBMTP_FILETYPE_OGG
      else FFIBindings::LIBMTP_FILETYPE_UNKNOWN
      end
    end

    #: (Integer result, String context) -> void
    def raise_on_error!(result, context)
      return if result.zero?

      device_handle = @device_handle
      if device_handle
        FFIBindings.LIBMTP_Dump_Errorstack(device_handle)
        FFIBindings.LIBMTP_Clear_Errorstack(device_handle)
      end
      raise Error, context
    end
  end
end
