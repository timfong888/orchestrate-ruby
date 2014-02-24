Gem::Specification.new do |s|
	s.name        = 'orchestrate-api'
	s.version     = '0.1.0'
	s.date        = '2014-02-18'
	s.summary     = 'Summary for orchestrate-api'
	s.description = 'Gem to interface with orchestrate.io api'
	s.authors     = ['James Carrasquer']
	s.email       = 'jimcar@aracnet.com'
	s.files       = ['lib/orchestrate-api.rb',
	                 'lib/orchestrate_api/procedural.rb',
	                 'lib/orchestrate_api/wrapper.rb',
	                 'lib/orchestrate_api/request.rb',
	                 'lib/orchestrate_api/response.rb'
	               ]
	s.homepage    = 'https://github.com/jimcar/orchestrate-api'
	s.license     = 'MIT'
	s.add_dependency "httparty"
	s.add_dependency "activerecord"
end