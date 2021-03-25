require 'bundler/setup'
require 'celluloid_pubsub'
require 'logger'

debug_enabled = (ENV['DEBUG'].present? && ENV['DEBUG'].to_s != 'false') || ENV['DEBUG'].blank?
log_file_path = File.join(File.expand_path(File.dirname(__FILE__)), 'log', 'celluloid_pubsub.log')
log_level = debug_enabled ?  ::Logger::Severity::DEBUG : ::Logger::Severity::INFO

Celluloid.task_class = if defined?(Celluloid::TaskThread)
                         Celluloid::TaskThread
                       else
                         Celluloid::Task::Threaded
                       end
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


# please don't use the BaseActor class to supervise actors. This is subject to change . This class is used only to test backward compatibility.
# For more information on how to supervise actors please see Celluloid wiki.
CelluloidPubsub::BaseActor.setup_actor_supervision(CelluloidPubsub::WebServer, actor_name: :web_server, args: {enable_debug: debug_enabled, spy: debug_enabled, adapter: nil,log_file_path: log_file_path, log_level: log_level })
if ENV['RUN_IN_PARALLEL'].nil? || ENV['RUN_IN_PARALLEL'].to_s.downcase == 'true'
  [
    { class: FirstActor, name: :first_actor },
    { class: SecondActor, name: :second_actor }
  ].pmap do |hash|
    CelluloidPubsub::BaseActor.setup_actor_supervision(hash[:class], actor_name: hash[:name], args: { enable_debug: debug_enabled, log_level: log_level })
  end
else
  CelluloidPubsub::BaseActor.setup_actor_supervision(FirstActor, actor_name: :first_actor, args: { enable_debug: debug_enabled, log_level: log_level })
  CelluloidPubsub::BaseActor.setup_actor_supervision(SecondActor, actor_name: :second_actor, args: { enable_debug: debug_enabled, log_level: log_level})
end

signal_received = false

Signal.trap('INT') do
  puts "\nAn interrupt signal has been triggered!"
  signal_received = true
end

Kernel.sleep 0.1 until signal_received
puts 'Exited succesfully! =)'
Celluloid.shutdown