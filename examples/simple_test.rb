require 'bundler/setup'
require 'celluloid_pubsub'

ENV['DEBUG_CELLULOID'] = ARGV.map(&:downcase).include?('debug') ? 'true' : 'false'
# actor that subscribes to a channel
class Subscriber
  include Celluloid
  include Celluloid::Logger

  def initialize
    @client = CelluloidPubsub::Client.connect(actor: Actor.current) do |ws|
      ws.subscribe('test_channel') # this will execute after the connection is opened
    end
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "subscriber got successful subscription #{message.inspect}"
      @client.publish('test_channel2', 'data' => ' subscriber got successfull subscription') # the message needs to be a Hash
    else
      puts "subscriber got message #{message.inspect}"
      @client.publish('test_channel2', 'data' => "subscriber got #{message}") # the message needs to be a Hash
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end
end

# actor that publishes a message in a channel
class Publisher
  include Celluloid
  include Celluloid::Logger

  def initialize
    @client = CelluloidPubsub::Client.connect(actor: Actor.current) do |ws|
      ws.subscribe('test_channel2') # this will execute after the connection is opened
    end
    @client.publish('test_channel', 'data' => 'my_message') # the message needs to be a Hash
    @client.publish('test_channel', 'data' => 'my_message')
    @client.publish('test_channel', 'data' => 'my_message')
  end

  def on_message(message)
    puts " publisher got #{message.inspect}"
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end
end

CelluloidPubsub::WebServer.supervise_as(:web_server)
Subscriber.supervise_as(:subscriber)
Publisher.supervise_as(:publisher)
sleep
