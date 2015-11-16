require File.expand_path('../lib/celluloid_pubsub/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'celluloid_pubsub'
  s.version = CelluloidPubsub.gem_version
  s.platform = Gem::Platform::RUBY
  s.summary = 'CelluloidPubsub is a simple ruby implementation of publish subscribe design patterns using celluloid actors and websockets, using Celluloid::Reel server'
  s.email = 'raoul_ice@yahoo.com'
  s.homepage = 'http://github.com/bogdanRada/celluloid_pubsub/'
  s.description = 'CelluloidPubsub is a simple ruby implementation of publish subscribe design patterns using celluloid actors and websockets, using Reel server for inter-process communication'
  s.authors = ['bogdanRada']
  s.date = Date.today

  s.licenses = ['MIT']
  s.files = `git ls-files`.split("\n")
  s.test_files = s.files.grep(/^(spec)/)
  s.require_paths = ['lib']


  s.add_runtime_dependency 'celluloid', '>= 0.16', '>= 0.16.0'
  s.add_runtime_dependency 'celluloid-io', '>= 0.16', '>= 0.16.2'
  s.add_runtime_dependency 'reel', '>= 0.5', '>= 0.5.0'
  s.add_runtime_dependency 'celluloid-websocket-client', '0.0.2'
  s.add_runtime_dependency 'activesupport', '>= 4.1', '>= 4.1.0'
  s.add_runtime_dependency 'versionomy', '>= 0.4', '>= 0.4.4'

  s.add_development_dependency 'rspec-rails', '~> 3.3', '>= 3.3'
  s.add_development_dependency 'guard', '~> 2.13', '>= 2.13'
  s.add_development_dependency 'guard-rspec', '~> 4.6', '>= 4.6'
  s.add_development_dependency 'simplecov', '~> 0.10', '>= 0.10'
  s.add_development_dependency 'simplecov-summary', '~> 0.0.4', '>= 0.0.4'
  s.add_development_dependency 'mocha', '~> 1.1', '>= 1.1'
  s.add_development_dependency 'coveralls', '~> 0.7', '>= 0.7'
  s.add_development_dependency 'rvm-tester', '~> 1.1', '>= 1.1'

  s.add_development_dependency 'rubocop', '~> 0.33', '>= 0.33'
  s.add_development_dependency 'phare', '~> 0.7', '>= 0.7'
  s.add_development_dependency 'yard', '~> 0.8', '>= 0.8.7'
  s.add_development_dependency 'yard-rspec', '~> 0.1', '>= 0.1'
  s.add_development_dependency 'redcarpet', '~> 3.3', '>= 3.3'
  s.add_development_dependency 'github-markup', '~> 1.3', '>= 1.3.3'
  s.add_development_dependency 'inch', '~> 0.6', '>= 0.6'
  s.add_development_dependency 'guard-inch', '~> 0.1', '>= 0.1.0'
end
