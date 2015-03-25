require 'bundler/setup'
require 'celluloid_pubsub'

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
    puts "subscriber got #{message.inspect}"
    @client.publish('test_channel2', 'data' => 'my_message') # the message needs to be a Hash
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
