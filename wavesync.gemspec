# frozen_string_literal: true

require_relative 'lib/wavesync/version'

Gem::Specification.new do |spec|
  spec.name    = 'wavesync'
  spec.version = Wavesync::VERSION
  spec.summary = 'Sync your music library to hardware devices like the teenage engineering TP-7 and Elektron Octatrack'
  spec.authors = ['Andreas Zecher']
  spec.homepage = 'https://github.com/pixelate/wavesync'
  spec.metadata['documentation_uri'] = 'https://github.com/pixelate/wavesync?tab=readme-ov-file#wavesync'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'config/**/*', 'LICENSE', 'README.md']
  spec.bindir        = 'bin'
  spec.executables   = ['wavesync']

  spec.add_dependency 'logger'
  spec.add_dependency 'rainbow', '~> 3.1'
  spec.add_dependency 'streamio-ffmpeg', '~> 3.0'
  spec.add_dependency 'taglib-ruby', '~> 2.0'
  spec.add_dependency 'tty-cursor', '~> 0.7.1'
  spec.add_dependency 'tty-prompt', '~> 0.23'
end
