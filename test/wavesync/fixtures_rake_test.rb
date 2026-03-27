# frozen_string_literal: true

require_relative 'test_case'

module Wavesync
  class FixturesRakeTest < Wavesync::TestCase
    test 'fixtures:generate runs without errors' do
      system('rake fixtures:generate', out: File::NULL, err: File::NULL)

      assert $CHILD_STATUS.success?
    end
  end
end
