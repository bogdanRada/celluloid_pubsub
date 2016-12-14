# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'simplecov'
require 'simplecov-summary'
require 'coveralls'

# require "codeclimate-test-reporter"
formatters = [SimpleCov::Formatter::SummaryFormatter, SimpleCov::Formatter::HTMLFormatter]

formatters << Coveralls::SimpleCov::Formatter # if ENV['TRAVIS']
# formatters << CodeClimate::TestReporter::Formatter # if ENV['CODECLIMATE_REPO_TOKEN'] && ENV['TRAVIS']

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(formatters)

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


# class used for testing actions
class TestActor
  include CelluloidPubsub::BaseActor

  def initialize(*_args)
  end
end
Celluloid.boot unless Celluloid.running?
CelluloidPubsub::BaseActor.setup_actor_supervision(TestActor, actor_name: :test_actor, args: { })

unless defined?(silence_stream) # Rails 5
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end
end
