# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gziprb/version'

Gem::Specification.new do |spec|
  spec.name = 'gziprb'
  spec.version = Gziprb::VERSION
  spec.authors = ['Owen Stephens']
  spec.email = ['owen@owenstephens.co.uk']

  spec.summary = 'A pure-ruby implementation of gzip/deflate'
  spec.licenses = ['MIT']
  spec.description = ''
  spec.homepage = 'https://www.github.com/owst/gziprb'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  unless spec.respond_to?(:metadata)
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'require_all', '~> 1.3'
  spec.add_dependency 'pqueue', '~> 2.1'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'awesome_print'
end
