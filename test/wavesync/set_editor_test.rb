# frozen_string_literal: true

require 'tmpdir'
require 'stringio'
require_relative 'test_case'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/set'
require_relative '../../lib/wavesync/set_editor'

module Wavesync
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
      assert_equal 'Hi Scores', e.send(:display_name, '01 Hi Scores.wav')
    end

    test 'display_name strips leading number and dot' do
      e = editor
      assert_equal 'Hi Scores', e.send(:display_name, '01. Hi Scores.wav')
    end

    test 'display_name strips leading number and dash' do
      e = editor
      assert_equal 'Hi Scores', e.send(:display_name, '01-Hi Scores.wav')
    end

    test 'display_name leaves name unchanged when no leading number' do
      e = editor
      assert_equal 'Hi Scores', e.send(:display_name, 'Hi Scores.wav')
    end

    test 'relative_path strips library prefix' do
      e = editor
      assert_equal 'House/01.wav', e.send(:relative_path, File.join(@library, 'House/01.wav'))
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
      e.send(:handle_action, :cursor_down)
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'cursor_down stops at last track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :cursor_down)
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'cursor_up moves selection back' do
      e = editor(track('a.wav'), track('b.wav'))
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :cursor_up)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'cursor_up stops at first track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.send(:handle_action, :cursor_up)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'cursor navigation is a no-op on empty set' do
      e = editor
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :cursor_up)
      assert_nil e.instance_variable_get(:@selected)
    end

    test 'remove_track removes the selected track' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :remove)
      assert_equal [a, c], e.instance_variable_get(:@set).tracks
    end

    test 'remove_track keeps selection in bounds when removing last track' do
      e = editor(track('a.wav'), track('b.wav'))
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :remove)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'remove_track sets selected to nil when set becomes empty' do
      e = editor(track('a.wav'))
      e.send(:handle_action, :remove)
      assert_nil e.instance_variable_get(:@selected)
    end

    test 'remove_track stops playback when removing the playing track' do
      a = track('a.wav')
      e = editor(a)
      e.instance_variable_set(:@player_track, a)
      e.instance_variable_set(:@player_state, :playing)
      e.expects(:stop_playback)
      e.send(:handle_action, :remove)
    end

    test 'remove_track does not stop playback when removing a different track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.instance_variable_set(:@player_track, b)
      e.instance_variable_set(:@player_state, :playing)
      e.expects(:stop_playback).never
      e.send(:handle_action, :remove)
    end

    test 'move_up moves selected track up and follows it' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :move_up)
      assert_equal [b, a, c], e.instance_variable_get(:@set).tracks
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'move_down moves selected track down and follows it' do
      a = track('a.wav')
      b = track('b.wav')
      c = track('c.wav')
      e = editor(a, b, c)
      e.send(:handle_action, :move_down)
      assert_equal [b, a, c], e.instance_variable_get(:@set).tracks
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'move_up is a no-op at the first track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.send(:handle_action, :move_up)
      assert_equal [a, b], e.instance_variable_get(:@set).tracks
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'move_down is a no-op at the last track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.send(:handle_action, :cursor_down)
      e.send(:handle_action, :move_down)
      assert_equal [a, b], e.instance_variable_get(:@set).tracks
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'move_track is a no-op with fewer than 2 tracks' do
      e = editor(track('a.wav'))
      e.send(:handle_action, :move_up)
      e.send(:handle_action, :move_down)
      assert_equal 0, e.instance_variable_get(:@selected)
    end

    test 'toggle_playback starts player on selected track' do
      a = track('a.wav')
      e = editor(a)
      e.expects(:start_player).with(a)
      e.send(:handle_action, :toggle_play)
    end

    test 'toggle_playback pauses a playing track' do
      a = track('a.wav')
      e = editor(a)
      e.instance_variable_set(:@player_track, a)
      e.instance_variable_set(:@player_state, :playing)
      e.instance_variable_set(:@player_started_at, Time.now)
      e.instance_variable_set(:@player_offset, 0)
      e.expects(:kill_player)
      e.send(:handle_action, :toggle_play)
      assert_equal :paused, e.instance_variable_get(:@player_state)
    end

    test 'toggle_playback resumes a paused track from saved offset' do
      a = track('a.wav')
      e = editor(a)
      e.instance_variable_set(:@player_track, a)
      e.instance_variable_set(:@player_state, :paused)
      e.instance_variable_set(:@player_offset, 15.0)
      e.expects(:start_player).with(a, 15.0)
      e.send(:handle_action, :toggle_play)
    end

    test 'toggle_playback switches track when a different track is selected' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.instance_variable_set(:@player_track, a)
      e.instance_variable_set(:@player_state, :playing)
      e.send(:handle_action, :cursor_down)
      e.expects(:stop_playback)
      e.expects(:start_player).with(b)
      e.send(:handle_action, :toggle_play)
    end

    test 'toggle_playback does nothing on empty set' do
      e = editor
      e.expects(:start_player).never
      e.send(:handle_action, :toggle_play)
    end

    test 'advance_and_play moves to next track and starts player' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.expects(:start_player).with(b)
      e.send(:advance_and_play)
      assert_equal 1, e.instance_variable_get(:@selected)
    end

    test 'advance_and_play does nothing at last track' do
      a = track('a.wav')
      b = track('b.wav')
      e = editor(a, b)
      e.send(:handle_action, :cursor_down)
      e.expects(:start_player).never
      e.send(:advance_and_play)
    end

    test 'advance_and_play does nothing when set is empty' do
      e = editor
      e.expects(:start_player).never
      e.send(:advance_and_play)
    end
  end
end
