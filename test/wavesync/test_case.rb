# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'

module Wavesync
  class TestCase < Minitest::Test
    def self.test(name, &)
      define_method("test_#{name.gsub(/\s+/, '_')}", &)
    end
  end
end
