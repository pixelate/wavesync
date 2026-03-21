# frozen_string_literal: true

require 'tmpdir'
require 'stringio'
require_relative 'test_case'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/set'
require_relative '../../lib/wavesync/set_editor'

module Wavesync
  Audio = Class.new unless defined?(Audio)

  class SetEditorTest < Wavesync::TestCase
    def setup
      @orig_stdout = $stdout
      $stdout = StringIO.new

      @tmp = Dir.mktmpdir
      @library = File.join(@tmp, 'library')
      FileUtils.mkdir_p(@library)

      UI.stubs(:new).returns(stub(color: '', clear: nil))
      TTY::Prompt.stubs(:new).returns(stub)
    end

    def teardown
      $stdout = @orig_stdout
      FileUtils.rm_rf(@tmp)
    end

    def editor(*tracks)
      set = Set.new(@library, 'test', tracks)
      SetEditor.new(set, @library)
    end

    def track(name)
      File.join(@library, name)
    end

    test 'display_name strips leading number and space' do
      e = editor
      assert_equal 'Hi Scores', e.display_name('01 Hi Scores.wav')
    end

    test 'display_name strips leading number and dot' do
      e = editor
      assert_equal 'Hi Scores', e.display_name('01. Hi Scores.wav')
    end

    test 'display_name strips leading number and dash' do
      e = editor
      assert_equal 'Hi Scores', e.display_name('01-Hi Scores.wav')
    end

    test 'display_name leaves name unchanged when no leading number' do
      e = editor
      assert_equal 'Hi Scores', e.display_name('Hi Scores.wav')
    end

    test 'relative_path strips library prefix' do
      e = editor
      assert_equal 'House/01.wav', e.relative_path(File.join(@library, 'House/01.wav'))
    end

    test 'cursor starts at 0 when tracks are present' do
      e = editor(track('a.wav'), track('b.wav'))
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'cursor starts as nil when set is empty' do
      e = editor
      assert_nil e.instance_variable_get(:@selected)
    end

    test 'cursor_down advances selection' do
      e = editor(track('a.wav'), track('b.wav'), track('c.wav'))
      e.handle_action(:cursor_down)
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'cursor_down stops at last track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.handle_action(:cursor_down)
      e.handle_action(:cursor_down)
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'cursor_up moves selection back' do
      e = editor(track('a.wav'), track('b.wav'))
      e.handle_action(:cursor_down)
      e.handle_action(:cursor_up)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'cursor_up stops at first track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.handle_action(:cursor_up)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'cursor navigation is a no-op on empty set' do
      e = editor
      e.handle_action(:cursor_down)
      e.handle_action(:cursor_up)
      assert_nil e.instance_variable_get(:@selected)
    end

    test 'remove_track removes the selected track' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.handle_action(:cursor_down)
      e.handle_action(:remove)
      assert_equal [a, c], e.instance_variable_get(:@set).tracks
    end

    test 'remove_track keeps selection in bounds when removing last track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.handle_action(:cursor_down)
      e.handle_action(:remove)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'remove_track sets selected to nil when set becomes empty' do
      e = editor(track('a.wav'))
      e.handle_action(:remove)
      assert_nil e.instance_variable_get(:@selected)
    end

    test 'remove_track stops playback when removing the playing track' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_state = :playing
      e.expects(:stop_playback)
      e.handle_action(:remove)
    end

    test 'remove_track does not stop playback when removing a different track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.player_track = b
      e.player_state = :playing
      e.expects(:stop_playback).never
      e.handle_action(:remove)
    end

    test 'move_up moves selected track up and follows it' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.handle_action(:cursor_down)
      e.handle_action(:move_up)
      assert_equal [b, a, c], e.instance_variable_get(:@set).tracks
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'move_down moves selected track down and follows it' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.handle_action(:move_down)
      assert_equal [b, a, c], e.instance_variable_get(:@set).tracks
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'move_up is a no-op at the first track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.handle_action(:move_up)
      assert_equal [a, b], e.instance_variable_get(:@set).tracks
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'move_down is a no-op at the last track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.handle_action(:cursor_down)
      e.handle_action(:move_down)
      assert_equal [a, b], e.instance_variable_get(:@set).tracks
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'move_track is a no-op with fewer than 2 tracks' do
      e = editor(track('a.wav'))
      e.handle_action(:move_up)
      e.handle_action(:move_down)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'toggle_playback starts player on selected track' do
      a = track('a.wav')
      e = editor(a)
      e.expects(:start_player).with(a)
      e.handle_action(:toggle_play)
    end

    test 'toggle_playback pauses a playing track' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_state = :playing
      e.player_started_at = Time.now
      e.player_offset = 0
      e.expects(:kill_player)
      e.handle_action(:toggle_play)
      assert_equal :paused, e.player_state
    end

    test 'toggle_playback resumes a paused track from saved offset' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_state = :paused
      e.player_offset = 15.0
      e.expects(:start_player).with(a, 15.0)
      e.handle_action(:toggle_play)
    end

    test 'toggle_playback switches track when a different track is selected' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.player_track = a
      e.player_state = :playing
      e.handle_action(:cursor_down)
      e.expects(:stop_playback)
      e.expects(:start_player).with(b)
      e.handle_action(:toggle_play)
    end

    test 'toggle_playback does nothing on empty set' do
      e = editor
      e.expects(:start_player).never
      e.handle_action(:toggle_play)
    end

    test 'advance_and_play moves to next track and starts player' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.expects(:start_player).with(b)
      e.advance_and_play
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'advance_and_play does nothing at last track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.handle_action(:cursor_down)
      e.expects(:start_player).never
      e.advance_and_play
    end

    test 'advance_and_play does nothing when set is empty' do
      e = editor
      e.expects(:start_player).never
      e.advance_and_play
    end

    test 'pitch_shift_semitones returns nil when source bpm is nil' do
      assert_nil editor.pitch_shift_semitones(nil, 128)
    end

    test 'pitch_shift_semitones returns nil when target bpm is nil' do
      assert_nil editor.pitch_shift_semitones(120, nil)
    end

    test 'pitch_shift_semitones returns nil when both bpms are nil' do
      assert_nil editor.pitch_shift_semitones(nil, nil)
    end

    test 'pitch_shift_semitones returns zero when bpms are equal' do
      assert_in_delta 0.0, editor.pitch_shift_semitones(120, 120), 0.0001
    end

    test 'pitch_shift_semitones returns positive value when target is higher' do
      assert_in_delta 12.0 * Math.log2(128.0 / 120.0), editor.pitch_shift_semitones(120, 128), 0.0001
    end

    test 'pitch_shift_semitones returns negative value when target is lower' do
      assert_in_delta 12.0 * Math.log2(120.0 / 128.0), editor.pitch_shift_semitones(128, 120), 0.0001
    end

    test 'format_pitch_shift includes plus sign for positive values' do
      assert_equal '+1.5', editor.format_pitch_shift(1.5)
    end

    test 'format_pitch_shift omits plus sign for negative values' do
      assert_equal '-1.5', editor.format_pitch_shift(-1.5)
    end

    test 'format_pitch_shift rounds to two decimal places' do
      assert_equal '+0.77', editor.format_pitch_shift(0.7654321)
    end

    test 'format_pitch_shift shows plus zero for zero' do
      assert_equal '+0.0', editor.format_pitch_shift(0.0)
    end

    test 'track_bpm returns nil for nil path' do
      assert_nil editor.track_bpm(nil)
    end

    test 'track_bpm returns nil when audio raises an error' do
      Audio.stubs(:new).raises(StandardError)
      assert_nil editor.track_bpm('/nonexistent/track.wav')
    end

    test 'track_bpm caches results' do
      mock_audio = stub(bpm: 120)
      Audio.expects(:new).once.returns(mock_audio)
      e = editor
      e.track_bpm('/some/track.wav')
      e.track_bpm('/some/track.wav')
    end

    test 'track_bpm returns bpm from audio file' do
      Audio.stubs(:new).returns(stub(bpm: 140))
      assert_equal 140, editor.track_bpm('/some/track.wav')
    end

    test 'track_duration returns nil for nil path' do
      assert_nil editor.track_duration(nil)
    end

    test 'track_duration returns nil when audio raises an error' do
      Audio.stubs(:new).raises(StandardError)
      assert_nil editor.track_duration('/nonexistent/track.wav')
    end

    test 'track_duration caches results' do
      mock_audio = stub(duration: 180.0)
      Audio.expects(:new).once.returns(mock_audio)
      e = editor
      e.track_duration('/some/track.wav')
      e.track_duration('/some/track.wav')
    end

    test 'track_duration returns duration from audio file' do
      Audio.stubs(:new).returns(stub(duration: 240.5))
      assert_in_delta 240.5, editor.track_duration('/some/track.wav'), 0.001
    end

    test 'format_duration formats whole minutes and seconds' do
      assert_equal '4:00', editor.format_duration(240.0)
    end

    test 'format_duration pads seconds with leading zero' do
      assert_equal '1:05', editor.format_duration(65.0)
    end

    test 'format_duration truncates fractional seconds' do
      assert_equal '3:20', editor.format_duration(200.9)
    end

    test 'format_duration returns nil for nil input' do
      assert_nil editor.format_duration(nil)
    end

    test 'format_duration handles zero' do
      assert_equal '0:00', editor.format_duration(0.0)
    end

    test 'playback_elapsed returns zero when stopped' do
      e = editor
      e.player_state = :stopped
      assert_in_delta 0.0, e.playback_elapsed, 0.001
    end

    test 'playback_elapsed returns offset when paused' do
      e = editor
      e.player_state = :paused
      e.player_offset = 42.5
      assert_in_delta 42.5, e.playback_elapsed, 0.001
    end

    test 'playback_elapsed sums offset and elapsed time when playing' do
      e = editor
      e.player_state = :playing
      e.player_offset = 10.0
      e.player_started_at = Time.now - 5
      assert_in_delta 15.0, e.playback_elapsed, 0.1
    end

    test 'visible_length returns character count ignoring ANSI codes' do
      colored = "\e[31mhello\e[0m"
      assert_equal 5, editor.visible_length(colored)
    end

    test 'visible_length returns full length for plain strings' do
      assert_equal 5, editor.visible_length('hello')
    end

    test 'track_cue_fractions returns empty array for nil path' do
      assert_equal [], editor.track_cue_fractions(nil)
    end

    test 'track_cue_fractions returns empty array when audio raises an error' do
      Audio.stubs(:new).raises(StandardError)
      assert_equal [], editor.track_cue_fractions('/nonexistent/track.wav')
    end

    test 'track_cue_fractions returns empty array when no cue points' do
      Audio.stubs(:new).returns(stub(sample_rate: 44_100, duration: 100.0, cue_points: []))
      assert_equal [], editor.track_cue_fractions('/some/track.wav')
    end

    test 'track_cue_fractions returns empty array when sample_rate is nil' do
      Audio.stubs(:new).returns(stub(sample_rate: nil, duration: 100.0, cue_points: []))
      assert_equal [], editor.track_cue_fractions('/some/track.wav')
    end

    test 'track_cue_fractions returns fractions for cue points' do
      cue_points = [
        { identifier: 1, sample_offset: 44_100, label: nil },
        { identifier: 2, sample_offset: 220_500, label: nil }
      ]
      Audio.stubs(:new).returns(stub(sample_rate: 44_100, duration: 100.0, cue_points: cue_points))
      fractions = editor.track_cue_fractions('/some/track.wav')
      assert_in_delta 0.01, fractions[0], 0.0001
      assert_in_delta 0.05, fractions[1], 0.0001
    end

    test 'track_cue_fractions caches results' do
      mock_audio = stub(sample_rate: 44_100, duration: 100.0, cue_points: [])
      Audio.expects(:new).once.returns(mock_audio)
      e = editor
      e.track_cue_fractions('/some/track.wav')
      e.track_cue_fractions('/some/track.wav')
    end

    test 'jump_to_next_cue does nothing when nothing is playing' do
      e = editor(track('a.wav'))
      e.expects(:start_player).never
      e.handle_action(:jump_to_next_cue)
    end

    test 'jump_to_next_cue does nothing when track has no cue points' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_state = :playing
      e.player_offset = 0
      e.player_started_at = Time.now
      e.stubs(:track_duration).returns(100.0)
      e.stubs(:track_cue_fractions).returns([])
      e.expects(:start_player).never
      e.handle_action(:jump_to_next_cue)
    end

    test 'jump_to_next_cue kills existing player before starting new one' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_index = 0
      e.player_state = :paused
      e.player_offset = 10.0
      e.stubs(:track_duration).returns(100.0)
      e.stubs(:track_cue_fractions).returns([0.5])
      kill_order = sequence('kill_then_start')
      e.expects(:kill_player).in_sequence(kill_order)
      e.expects(:start_player).in_sequence(kill_order)
      e.handle_action(:jump_to_next_cue)
    end

    test 'jump_to_next_cue jumps to next cue after current position' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_index = 0
      e.player_state = :paused
      e.player_offset = 10.0
      e.stubs(:track_duration).returns(100.0)
      e.stubs(:track_cue_fractions).returns([0.2, 0.5, 0.8])
      e.expects(:start_player).with(a, 20.0, player_index: 0)
      e.handle_action(:jump_to_next_cue)
    end

    test 'jump_to_next_cue cycles to first cue when past last cue' do
      a = track('a.wav')
      e = editor(a)
      e.player_track = a
      e.player_index = 0
      e.player_state = :paused
      e.player_offset = 85.0
      e.stubs(:track_duration).returns(100.0)
      e.stubs(:track_cue_fractions).returns([0.2, 0.5, 0.8])
      e.expects(:start_player).with(a, 20.0, player_index: 0)
      e.handle_action(:jump_to_next_cue)
    end

    test 'jump_to_next_cue preserves player_index when cursor is on different track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.player_track = a
      e.player_index = 0
      e.handle_action(:cursor_down)
      e.player_state = :paused
      e.player_offset = 10.0
      e.stubs(:track_duration).returns(100.0)
      e.stubs(:track_cue_fractions).returns([0.5])
      e.expects(:start_player).with(a, 50.0, player_index: 0)
      e.handle_action(:jump_to_next_cue)
    end

    test 'playback_bar places cue point marker at correct position' do
      e = editor
      e.instance_variable_get(:@ui).expects(:color).with('░░░░░', :surface).twice.returns('')
      e.instance_variable_get(:@ui).expects(:color).with('◆', :surface).once.returns('')
      e.playback_bar(0.0, 100.0, 11, cue_fractions: [0.5])
    end

    test 'playback_bar does not place cue markers when none given' do
      e = editor
      e.instance_variable_get(:@ui).expects(:color).with('░░░░░░░░░░', :surface).once.returns('')
      e.playback_bar(0.0, 100.0, 10)
    end

    test 'playback_bar colors cue at playhead with highlight' do
      e = editor
      e.instance_variable_get(:@ui).stubs(:color).returns('')
      e.instance_variable_get(:@ui).expects(:color).with('◆', :highlight).returns('').once
      e.playback_bar(50.0, 100.0, 10, cue_fractions: [0.5])
    end

    test 'playback_bar colors cue not at playhead with surface color' do
      e = editor
      e.instance_variable_get(:@ui).stubs(:color).returns('')
      e.instance_variable_get(:@ui).expects(:color).with('◆', :surface).returns('').once
      e.playback_bar(0.0, 100.0, 10, cue_fractions: [0.5])
    end
  end
end
