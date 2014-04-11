lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'orchestrate/version'

Gem::Specification.new do |s|
	s.name          = 'orchestrate-api'
	s.version       = Orchestrate::VERSION
	s.date          = '2014-03-23'
	s.authors       = ['James Carrasquer']
	s.email         = ['jimcar@aracnet.com']
	s.summary       = 'Summary for orchestrate-api'
	s.description   = 'Client for the Orchestrate REST API'
	s.homepage      = 'https://github.com/jimcar/orchestrate-api'
	s.license       = 'MIT'

	s.files         = `git ls-files -z`.split("\x0")
	s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
	s.test_files    = s.files.grep(%r{^(test|spec|features)/})
	s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.6"
  s.add_development_dependency "rake"
	s.add_development_dependency "vcr"
	s.add_development_dependency "webmock"
end