# frozen_string_literal: true

require 'rake/testtask'
require_relative 'lib/wavesync/version'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

task default: :test

namespace :release do
  desc 'Tag, push, build, and publish the gem for the current version'
  task :publish do
    version = Wavesync::VERSION
    tag = "v#{version}"
    gem_file = "wavesync-#{version}.gem"

    sh "git tag #{tag}"
    sh "git push origin #{tag}"
    sh 'gem build wavesync.gemspec'
    sh "gem push #{gem_file}"
  end
end
