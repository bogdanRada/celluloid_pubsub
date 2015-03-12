require 'bundler/setup'
require 'celluloid_pubsub'

class Subscriber
  include Celluloid
  include Celluloid::Logger

  def initialize
    CelluloidPubsub::Client.connect(actor: Actor.current) do |ws|
      ws.subscribe('test_channel') # this will execute after the connection is opened
    end
  end

  def on_message(message)
    puts "got #{message.inspect}"
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
   end
  end

class Publisher
  include Celluloid
  include Celluloid::Logger

  def initialize
    CelluloidPubsub::Client.connect(actor: Actor.current) do |ws|
      ws.publish('test_channel', 'data' => 'my_message') # the message needs to be a Hash
    end
  end
end

CelluloidPubsub::WebServer.supervise_as(:web_server)
Subscriber.supervise_as(:subscriber)
Publisher.supervise_as(:publisher)
sleep
