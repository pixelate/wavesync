# frozen_string_literal: true

require 'rake/testtask'
require_relative 'lib/wavesync/version'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/wavesync/**/*_test.rb'
  t.verbose = false
end

namespace :test do
  desc 'Run integration tests against connected devices'
  Rake::TestTask.new(:integration) do |t|
    t.libs << 'test'
    t.pattern = 'test/integration/**/*_test.rb'
    t.verbose = false
  end
end

desc 'Run rubocop, steep check, and tests'
task default: %i[rubocop steep test]

task :rubocop do
  sh 'rubocop -A'
end

task :steep do
  sh 'steep check'
end

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
