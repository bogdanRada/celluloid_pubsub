# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'
ENV['APP_ENV'] = 'test'
require 'bundler/setup'
require 'rspec'
require 'rspec/expectations'
require 'rspec/mocks'
require 'rspec/support'
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
  add_filter 'lib/celluloid_pubsub/version'

  at_exit {}
end

# CodeClimate::TestReporter.configure do |config|
#  config.logger.level = Logger::WARN
# end
# CodeClimate::TestReporter.start
require 'celluloid_pubsub'
require 'logger'
Celluloid.task_class = if defined?(Celluloid::TaskThread)
                         Celluloid::TaskThread
                       else
                         Celluloid::Task::Threaded
                       end
Celluloid.logger = ::Logger.new(STDOUT)

def celluloid_running?
  begin
    Celluloid.running?
  rescue StandardError
    false
  end
end

RSpec.configure do |config|
  config.include RSpec::Matchers

  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  config.around(:each) do |example|
    Celluloid.shutdown if celluloid_running?
    Celluloid.boot
    example.run
    Celluloid.shutdown if celluloid_running?
  end

  config.after(:suite) do
    if SimpleCov.running
      silence_stream(STDOUT) do
        SimpleCov::Formatter::HTMLFormatter.new.format(SimpleCov.result)
      end

      SimpleCov::Formatter::SummaryFormatter.new.format(SimpleCov.result)
    end
  end
end

def example_addr; '127.0.0.1'; end
def example_port; 1234; end
def example_path; "/example"; end
def example_url;  "http://#{example_addr}:#{example_port}#{example_path}"; end

def with_socket_pair
  logfile = File.open(File.expand_path('../log/test.log', __dir__), 'a')
  server = CelluloidPubsub::WebServer.new(
    hostname: example_addr,
    port: example_port,
    path: example_path,
    enable_debug: true,
    spy: true,
    backlog: 1024,
    adapter: nil,
    log_file_path: logfile,
    log_level: ::Logger::Severity::DEBUG
  )
  yield server
ensure
  server.terminate if server && server.alive?
end

# class used for testing actions
class TestActor
  include CelluloidPubsub::BaseActor

  def initialize(*_args); end
end
CelluloidPubsub::BaseActor.boot_up
CelluloidPubsub::BaseActor.setup_actor_supervision(TestActor, actor_name: :test_actor, args: {})

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
