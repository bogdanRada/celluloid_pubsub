require 'bundler/setup'
require 'celluloid_pubsub'
require 'logger'

debug_enabled = ENV['DEBUG'].present? && ENV['DEBUG'].to_s == 'true'

if debug_enabled == true
  log_file_path = File.join(File.expand_path(File.dirname(__FILE__)), 'log', 'celluloid_pubsub.log')
  puts log_file_path
  puts CelluloidPubsub::BaseActor.celluloid_version
  puts CelluloidPubsub::BaseActor.version_less_than_sixten?
  FileUtils.rm(log_file_path) if File.exist?(log_file_path)
  FileUtils.mkdir_p(File.dirname(log_file_path))
  log_file = File.open(log_file_path, 'w')
  log_file.sync = true
  $CELLULOID_DEBUG = true
  Celluloid.logger = ::Logger.new(log_file_path)
end

# actor that subscribes to a channel
class Subscriber < CelluloidPubsub::BaseActor

  def initialize(options = {})
    @client = CelluloidPubsub::Client.connect({ actor: Actor.current, channel: 'test_channel' }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "subscriber got successful subscription #{message.inspect}"
      @client.publish('test_channel2', 'data' => ' subscriber got successfull subscription') # the message needs to be a Hash
    else
      puts "subscriber got message #{message.inspect}"
      @client.unsubscribe('test_channel')
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end
end

# actor that publishes a message in a channel
class Publisher < CelluloidPubsub::BaseActor

  def initialize(options = {})
    @client = CelluloidPubsub::Client.connect({ actor: Actor.current, channel: 'test_channel2' }.merge(options))
    @client.publish('test_channel', 'data' => 'my_message') # the message needs to be a Hash
  end

  def on_message(message)
    puts " publisher got #{message.inspect}"
    @client.unsubscribe('test_channel2')
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end
end

CelluloidPubsub::BaseActor.setup_actor_supervision(CelluloidPubsub::WebServer, actor_name: :web_server, args: {enable_debug: debug_enabled })
CelluloidPubsub::BaseActor.setup_actor_supervision(Subscriber, actor_name: :subscriber, args: {enable_debug: debug_enabled })
CelluloidPubsub::BaseActor.setup_actor_supervision(Publisher, actor_name: :publisher, args: {enable_debug: debug_enabled })

sleep
