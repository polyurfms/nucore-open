# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "version"

Gem::Specification.new do |gem|
  gem.name          = "sc_relay"
  gem.version       = ScRelay::VERSION
  gem.authors       = ""
  gem.email         = ""
  gem.description   = ""
  gem.summary       = ""
  gem.homepage      = ""

  gem.files         = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})

  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'nokogiri', '>= 1.6'

  gem.add_development_dependency 'rspec', '~> 3.6'
  gem.add_development_dependency 'vcr', '~> 2.8'
  gem.add_development_dependency 'webmock'
end
