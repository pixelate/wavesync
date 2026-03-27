# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'

module Wavesync
  class TestCase < Minitest::Test
    FIXTURES_PATH = File.expand_path('../fixtures', __dir__).freeze
    def self.test(name, &)
      define_method("test_#{name.gsub(/\s+/, '_')}", &)
    end

    private

    def silence_output
      @original_stdout = $stdout
      @null_out = File.open(File::NULL, 'w') # rubocop:disable Style/FileOpen
      $stdout = @null_out
    end

    def restore_output
      $stdout = @original_stdout
      @null_out&.close
    end
  end
end
