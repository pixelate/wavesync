# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/timing'

module Wavesync
  class TimingTest < Wavesync::TestCase
    def setup
      Timing.reset
    end

    test 'measure accumulates time into the named bucket' do
      Timing.current.measure(:probe) { sleep(0.01) }

      assert_operator Timing.current.totals[:probe], :>=, 0.01
    end

    test 'measure accumulates across multiple calls into the same bucket' do
      Timing.current.measure(:probe) { sleep(0.005) }
      Timing.current.measure(:probe) { sleep(0.005) }

      assert_operator Timing.current.totals[:probe], :>=, 0.01
    end

    test 'measure tracks separate buckets independently' do
      Timing.current.measure(:probe) { sleep(0.005) }
      Timing.current.measure(:transcode) { sleep(0.005) }

      totals = Timing.current.totals
      assert_operator totals[:probe], :>=, 0.005
      assert_operator totals[:transcode], :>=, 0.005
    end

    test 'measure returns the block result' do
      result = Timing.current.measure(:probe) { 42 }

      assert_equal 42, result
    end

    test 'measure records time even when the block raises' do
      assert_raises(RuntimeError) do
        Timing.current.measure(:probe) do
          sleep(0.005)
          raise 'boom'
        end
      end

      assert_operator Timing.current.totals[:probe], :>=, 0.005
    end

    test 'reset clears accumulated totals' do
      Timing.current.measure(:probe) { sleep(0.005) }
      Timing.reset

      assert_equal({}, Timing.current.totals)
    end

    test 'totals returns a copy that cannot mutate internal state' do
      Timing.current.measure(:probe) { sleep(0.001) }
      copy = Timing.current.totals
      copy[:probe] = 999

      refute_equal 999, Timing.current.totals[:probe]
    end

    test 'totals returns an empty hash before any measurement' do
      assert_equal({}, Timing.current.totals)
    end
  end
end
