# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'

module Wavesync
  class TestCase < Minitest::Test
    FIXTURES_PATH = File.expand_path('../fixtures', __dir__).freeze
    def self.test(name, &)
      define_method("test_#{name.gsub(/\s+/, '_')}", &)
    end
  end
end
