# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'pathname'
require 'zlib'
require_relative 'audio'

module Wavesync
  class OctatrackExporter
    PROJECT_FILE = 'project.work'
    CRLF = "\r\n"

    TEMPLATES_DIR = File.join(__dir__.to_s, 'octatrack_project_files')

    # Offsets of the 8 track assignment blocks within each bank file.
    # Each block is 40 bytes: 8 × [0x8N, slot, slot, 0x00, 0x00]
    TRACK_ASSIGNMENT_OFFSETS = [
      0x8f1ad, 0x90a68, 0x92323, 0x93bde,
      0x95499, 0x96d54, 0x9860f, 0x99eca
    ].freeze

    #: (Set set, String library_path, String device_audio_path, String projects_path, ?device: Device?) -> void
    def initialize(set, library_path, device_audio_path, projects_path, device: nil)
      @set = set #: Set
      @library_path = File.expand_path(library_path) #: String
      @device_audio_path = File.expand_path(device_audio_path) #: String
      @projects_path = File.expand_path(projects_path) #: String
      @device = device #: Device?
    end

    #: () -> String
    def project_dir
      File.join(@projects_path, @set.name.upcase)
    end

    #: () -> String
    def export
      FileUtils.mkdir_p(project_dir)
      write_project_work
      write_bank_files
      write_arr_files
      write_markers_file
      system('sync')
      project_dir
    end

    private

    #: () -> void
    def write_project_work
      File.write(File.join(project_dir, PROJECT_FILE), generate_project_work)
    end

    #: () -> void
    def write_bank_files
      bank_template = load_template('bank')
      bank01 = apply_track_assignments(bank_template)
      File.binwrite(File.join(project_dir, 'bank01.work'), bank01)
      2.upto(16) do |n|
        File.binwrite(File.join(project_dir, "bank#{n.to_s.rjust(2, '0')}.work"), bank_template)
      end
    end

    #: () -> void
    def write_arr_files
      arr_template = load_template('arr')
      1.upto(8) do |n|
        File.binwrite(File.join(project_dir, "arr#{n.to_s.rjust(2, '0')}.work"), arr_template)
      end
    end

    #: () -> void
    def write_markers_file
      File.binwrite(File.join(project_dir, 'markers.work'), load_template('markers'))
    end

    #: (String name) -> String
    def load_template(name)
      Zlib::GzipReader.open(File.join(TEMPLATES_DIR, "#{name}_template.gz"), &:read) #: String
    end

    #: (String bank_data) -> String
    def apply_track_assignments(bank_data)
      data = bank_data.dup.b
      TRACK_ASSIGNMENT_OFFSETS.each do |offset|
        write_track_assignments(data, offset)
      end
      data.setbyte(data.bytesize - 1, bank_checksum(data))
      data
    end

    #: (String data, Integer offset) -> void
    def write_track_assignments(data, offset)
      slot_for_track = {
        0 => 1,  # Track 1 → song 1
        4 => 2   # Track 5 → song 2
      }
      8.times do |track|
        pos = offset + (track * 5)
        slot = slot_for_track.fetch(track, 0)
        data.setbyte(pos,     0x80 | track)
        data.setbyte(pos + 1, slot)
        data.setbyte(pos + 2, slot)
        data.setbyte(pos + 3, 0)
        data.setbyte(pos + 4, 0)
      end
    end

    #: (String data) -> Integer
    def bank_checksum(data)
      ((data.byteslice(0, data.bytesize - 1) || '').bytes.sum - 1) % 256
    end

    #: () -> String
    def generate_project_work
      parts = [
        section_header('Project Settings'),
        meta_section,
        settings_section,
        section_header('Project States'),
        states_section,
        section_header('Samples'),
        flex_sample_sections,
        static_sample_sections,
        divider
      ]
      parts.join(CRLF)
    end

    #: () -> String
    def divider
      '############################'
    end

    #: (String title) -> String
    def section_header(title)
      [divider, "# #{title}", divider, ''].join(CRLF)
    end

    #: (String tag, Array[String] lines) -> String
    def block(tag, lines)
      ([open_tag(tag)] + lines + [close_tag(tag), '']).join(CRLF)
    end

    #: (String tag) -> String
    def open_tag(tag)
      "[#{tag}]"
    end

    #: (String tag) -> String
    def close_tag(tag)
      "[/#{tag}]"
    end

    #: () -> String
    def meta_section
      block('META', [
              'TYPE=OCTATRACK DPS-1 PROJECT',
              'VERSION=19',
              'OS_VERSION=R0175     1.40A'
            ])
    end

    #: () -> String
    def settings_section
      block('SETTINGS', [
              'WRITEPROTECTED=0',
              'TEMPOx24=2880',
              'PATTERN_TEMPO_ENABLED=0',
              'MIDI_CLOCK_SEND=0',
              'MIDI_CLOCK_RECEIVE=0',
              'MIDI_TRANSPORT_SEND=0',
              'MIDI_TRANSPORT_RECEIVE=0',
              'MIDI_PROGRAM_CHANGE_SEND=0',
              'MIDI_PROGRAM_CHANGE_SEND_CH=-1',
              'MIDI_PROGRAM_CHANGE_RECEIVE=0',
              'MIDI_PROGRAM_CHANGE_RECEIVE_CH=-1',
              'MIDI_TRIG_CH1=0',
              'MIDI_TRIG_CH2=1',
              'MIDI_TRIG_CH3=2',
              'MIDI_TRIG_CH4=3',
              'MIDI_TRIG_CH5=4',
              'MIDI_TRIG_CH6=5',
              'MIDI_TRIG_CH7=6',
              'MIDI_TRIG_CH8=7',
              'MIDI_AUTO_CHANNEL=10',
              'MIDI_SOFT_THRU=0',
              'MIDI_AUDIO_TRK_CC_IN=1',
              'MIDI_AUDIO_TRK_CC_OUT=3',
              'MIDI_AUDIO_TRK_NOTE_IN=1',
              'MIDI_AUDIO_TRK_NOTE_OUT=3',
              'MIDI_MIDI_TRK_CC_IN=1',
              'PATTERN_CHANGE_CHAIN_BEHAVIOR=0',
              'PATTERN_CHANGE_AUTO_SILENCE_TRACKS=0',
              'PATTERN_CHANGE_AUTO_TRIG_LFOS=0',
              'LOAD_24BIT_FLEX=0',
              'DYNAMIC_RECORDERS=0',
              'RECORD_24BIT=0',
              'RESERVED_RECORDER_COUNT=8',
              'RESERVED_RECORDER_LENGTH=16',
              'INPUT_DELAY_COMPENSATION=0',
              'GATE_AB=127',
              'GATE_CD=127',
              'GAIN_AB=64',
              'GAIN_CD=64',
              'DIR_AB=0',
              'DIR_CD=0',
              'PHONES_MIX=64',
              'MAIN_TO_CUE=0',
              'MASTER_TRACK=0',
              'CUE_STUDIO_MODE=0',
              'MAIN_LEVEL=64',
              'CUE_LEVEL=64',
              'METRONOME_TIME_SIGNATURE=3',
              'METRONOME_TIME_SIGNATURE_DENOMINATOR=2',
              'METRONOME_PREROLL=0',
              'METRONOME_CUE_VOLUME=32',
              'METRONOME_MAIN_VOLUME=0',
              'METRONOME_PITCH=12',
              'METRONOME_TONAL=1',
              'METRONOME_ENABLED=0',
              *Array.new(8, 'TRIG_MODE_MIDI=0')
            ])
    end

    #: () -> String
    def states_section
      block('STATES', [
              'BANK=0',
              'PATTERN=0',
              'ARRANGEMENT=0',
              'ARRANGEMENT_MODE=0',
              'PART=0',
              'TRACK=4',
              'TRACK_OTHERMODE=0',
              'SCENE_A_MUTE=0',
              'SCENE_B_MUTE=0',
              'TRACK_CUE_MASK=0',
              'TRACK_MUTE_MASK=0',
              'TRACK_SOLO_MASK=0',
              'MIDI_TRACK_MUTE_MASK=0',
              'MIDI_TRACK_SOLO_MASK=0',
              'MIDI_MODE=0'
            ])
    end

    #: () -> String
    def flex_sample_sections
      (129..136).map do |slot|
        block('SAMPLE', [
                'TYPE=FLEX',
                "SLOT=#{slot}",
                'PATH=',
                'BPMx24=2880',
                'TSMODE=2',
                'LOOPMODE=0',
                'GAIN=72',
                'TRIGQUANTIZATION=-1'
              ])
      end.join(CRLF)
    end

    #: () -> String
    def static_sample_sections
      @set.tracks.each_with_index.map do |track_path, index|
        slot = index + 1
        path = relative_audio_path(track_path)
        static_sample_block(slot, path)
      end.join(CRLF)
    end

    #: (Integer slot, String path) -> String
    def static_sample_block(slot, path)
      block('SAMPLE', [
              'TYPE=STATIC',
              "SLOT=#{slot.to_s.rjust(3, '0')}",
              "PATH=#{path}",
              'TSMODE=2',
              'LOOPMODE=0',
              'GAIN=48',
              'TRIGQUANTIZATION=-1'
            ])
    end

    #: (String track_path) -> String
    def relative_audio_path(track_path)
      audio_folder = File.basename(@device_audio_path)
      relative_to_library = track_path.delete_prefix("#{@library_path}/")
      relative_to_library = apply_device_path_rules(track_path, relative_to_library) if @device
      File.join('..', audio_folder, relative_to_library)
    end

    #: (String track_path, String relative_to_library) -> String
    def apply_device_path_rules(track_path, relative_to_library)
      target_type = @device.target_file_type(track_path)
      relative_path = Pathname(relative_to_library)
      relative_path = relative_path.sub_ext(".#{target_type}") if target_type

      if @device.bpm_source == :filename
        bpm = read_bpm(track_path)
        if bpm
          bpm_basename = "#{relative_path.basename(relative_path.extname)} #{bpm} bpm#{relative_path.extname}"
          relative_path = relative_path.dirname.join(bpm_basename)
        end
      end

      relative_path.to_s
    end

    #: (String track_path) -> (String | Integer)?
    def read_bpm(track_path)
      Audio.new(track_path).bpm
    rescue StandardError
      nil
    end
  end
end
