# frozen_string_literal: true

require 'minitest/autorun'

module Wavesync
  class TestCase < Minitest::Test
    def self.test(name, &block)
      define_method("test_#{name.gsub(/\s+/, '_')}", &block)
    end
  end
end
