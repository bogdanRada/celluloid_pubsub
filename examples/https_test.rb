require 'bundler/setup'
require 'celluloid_pubsub'
require 'logger'

$stdout.sync = true
$stderr.sync = true
$stdin.sync = true

debug_enabled = ENV['DEBUG'].present? && ENV['DEBUG'].to_s == 'true'
log_file_path = File.join(File.expand_path(File.dirname(__FILE__)), 'log', 'celluloid_pubsub.log')

# actor that subscribes to a channel
class FirstActor
  include Celluloid

  def initialize(options = {})
    @client = CelluloidPubsub::Client.new({ actor: Actor.current, channel: 'test_channel' }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "subscriber got successful subscription #{message}"
      @client.publish('test_channel2', 'data' => ' subscriber got successfull subscription') # the message needs to be a Hash
    else
      puts "subscriber got message #{message}"
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end


end

# actor that publishes a message in a channel
class SecondActor
  include Celluloid

  def initialize(options = {})
    @client = CelluloidPubsub::Client.new({ actor: Actor.current, channel: 'test_channel2' }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "publisher got successful subscription #{message}"
      @client.publish('test_channel', 'data' => ' my_message') # the message needs to be a Hash
    else
      puts "publisher got message #{message}"
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end

end

options = {
  :cert => File.read(File.expand_path("../tmp/certs/server.crt", __FILE__)),
  :key  => File.read(File.expand_path("../tmp/certs/server.key", __FILE__))
}

# please don't use the BaseActor class to supervise actors. This is subject to change . This class is used only to test backward compatibility.
# For more information on how to supervise actors please see Celluloid wiki.
CelluloidPubsub::BaseActor.setup_actor_supervision(CelluloidPubsub::Server::HTTPS, actor_name: :web_server, args: options)
CelluloidPubsub::BaseActor.setup_actor_supervision(FirstActor, actor_name: :first_actor, args: {quiet: debug_enabled })
#CelluloidPubsub::BaseActor.setup_actor_supervision(SecondActor, actor_name: :second_actor, args: {quiet: debug_enabled })

signal_received = false

Signal.trap('INT') do
  puts "\nAn interrupt signal has been triggered!"
  signal_received = true
end

sleep 0.1 until signal_received
puts 'Exited succesfully! =)'
