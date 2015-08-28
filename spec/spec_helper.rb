# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov-summary'
require 'coveralls'

# require "codeclimate-test-reporter"
formatters = [SimpleCov::Formatter::HTMLFormatter]

formatters << Coveralls::SimpleCov::Formatter # if ENV['TRAVIS']
# formatters << CodeClimate::TestReporter::Formatter # if ENV['CODECLIMATE_REPO_TOKEN'] && ENV['TRAVIS']

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[*formatters]

Coveralls.wear!
SimpleCov.start 'rails' do
  add_filter 'spec'

  at_exit {}
end

# CodeClimate::TestReporter.configure do |config|
#  config.logger.level = Logger::WARN
# end
# CodeClimate::TestReporter.start

require 'bundler/setup'
require 'celluloid_pubsub'

RSpec.configure do |config|
  require 'rspec/expectations'
  config.include RSpec::Matchers

  config.mock_with :mocha

  config.after(:suite) do
    if SimpleCov.running
      silence_stream(STDOUT) do
        SimpleCov::Formatter::HTMLFormatter.new.format(SimpleCov.result)
      end

      SimpleCov::Formatter::SummaryFormatter.new.format(SimpleCov.result)
    end
  end
end
CelluloidPubsub::Config.backward_compatible

# class used for testing actions
class TestActor
  include Celluloid
  include CelluloidPubsub::Config.config['logger_class']
end

TestActor.supervise(as: :test_actor)
