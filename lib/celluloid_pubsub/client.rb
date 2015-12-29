require_relative './helper'
module CelluloidPubsub
  # worker that subscribes to a channel or publishes to a channel
  # if it used to subscribe to a channel the worker will dispatch the messages to the actor that made the
  # connection in the first place.
  #
  # @!attribute actor
  #   @return [Celluloid::Actor] actor to which callbacks will be delegated to
  #
  # @!attribute connect_blk
  #   @return [Proc] Block  that will execute after the connection is opened
  #
  # @!attribute connection
  #   @return [Celluloid::WebSocket::Client] A websocket connection that is used to chat witht the webserver
  #
  # @!attribute options
  #   @return [Hash] the options that can be used to connect to webser and send additional data
  #
  # @!attribute hostname
  #   @return [String] The hostname on which the webserver runs on
  #
  # @!attribute port
  #  @return [String] The port on which the webserver runs on
  #
  # @!attribute path
  #   @return [String] The hostname on which the webserver runs on
  class Client
    include Celluloid
    include Celluloid::Logger
    include CelluloidPubsub::Helper

    attr_reader :actor, :connection, :options, :hostname, :port, :path, :channel
    finalizer :shutdown
    #  receives a list of options that are used to connect to the webserver and an actor to which the callbacks are delegated to
    #  when receiving messages from a channel
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String] :actor The actor that made the connection
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [String] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    #
    # @param [Proc] connect_blk  Block  that will execute after the connection is opened
    #
    # @return [void]
    #
    # @api public
    def initialize(options)
      @options = options.stringify_keys!
      @actor ||= @options.fetch('actor', nil)
      @channel ||= @options.fetch('channel', nil)
      raise "#{self}: Please provide an actor in the options list!!!" if @actor.blank?
      raise "#{self}: Please provide an channel in the options list!!!" if @channel.blank?
      supervise_actors
      setup_celluloid_exception_handling
    end

    def log_file_path
      @log_file_path ||= @options.fetch('log_file_path', nil)
    end
    
    # the method will link the current actor to the actor that is attached to, and the connection to the current actor
    #
    # @return [void]
    #
    # @api public
    def supervise_actors
      current_actor = Actor.current
      @actor.link current_actor if @actor.respond_to?(:link)
      current_actor.link connection
    end

    # the method will return the client that is used to
    #
    #
    # @return [Celluloid::WebSocket::Client] the websocket connection used to connect to server
    #
    # @api public
    def connection
      @connection ||= Celluloid::WebSocket::Client.new("ws://#{hostname}:#{port}#{path}", Actor.current)
    end

    def hostname
      @hostname ||= @options.fetch('hostname', CelluloidPubsub::WebServer::HOST)
    end

    def port
      @port ||= @options.fetch('port', CelluloidPubsub::WebServer::PORT)
    end

    def path
      @path ||= @options.fetch('path', CelluloidPubsub::WebServer::PATH)
    end

    # the method will terminate the current actor
    #
    #
    # @return [void]
    #
    # @api public
    def shutdown
      log_debug "#{self.class} tries to 'shudown'"
      terminate
    end

    #  checks if debug is enabled
    #
    #
    # @return [boolean]
    #
    # @api public
    def debug_enabled?
      @options.fetch('enable_debug', false).to_s == 'true'
    end

    # subscribes to a channel . need to be used inside the connect block passed to the actor
    #
    # @param [string] channel
    #
    # @return [void]
    #
    # @api public
    def subscribe(channel)
      log_debug("#{@actor.class} tries to subscribe to channel  #{channel}")
      async.send_action('subscribe', channel)
    end

    # publishes to a channel some data (can be anything)
    #
    # @param [string] channel
    # @param [#to_s] data
    #
    # @return [void]
    #
    # @api public
    def publish(channel, data)
      send_action('publish', channel, data)
    end

    # unsubscribes current client from a channel
    #
    # @param [string] channel
    #
    # @return [void]
    #
    # @api public
    def unsubscribe(channel)
      send_action('unsubscribe', channel)
    end

    # unsubscribes all clients subscribed to a channel
    #
    # @param [string] channel
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_clients(channel)
      send_action('unsubscribe_clients', channel)
    end

    # unsubscribes all clients from all channels
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all
      send_action('unsubscribe_all')
    end

    #  callback executes after connection is opened and delegates action to actor
    #
    # @return [void]
    #
    # @api public
    def on_open
      log_debug("#{@actor.class} websocket connection opened")
      async.subscribe(@channel)
    end

    def log_debug(message)
      debug message if debug_enabled?
    end

    # callback executes when actor receives a message from a subscribed channel
    # and parses the message using JSON.parse and dispatches the parsed
    # message to the original actor that made the connection
    #
    # @param [JSON] data
    #
    # @return [void]
    #
    # @api public
    def on_message(data)
      message = JSON.parse(data)
      log_debug("#{@actor.class} received JSON  #{message}")
      @actor.async.on_message(message)
    end

    # callback executes when connection closes
    #
    # @param [String] code
    #
    # @param [String] reason
    #
    # @return [void]
    #
    # @api public
    def on_close(code, reason)
      connection.terminate
      terminate
      log_debug("#{@actor.class} dispatching on close  #{code} #{reason}")
      @actor.async.on_close(code, reason)
    end

  private

    # method used to send an action to the webserver reactor , to a chanel and with data
    #
    # @param [String] action
    # @param [String] channel
    # @param [Hash] data
    #
    # @return [void]
    #
    # @api private
    def send_action(action, channel = nil, data = {})
      data = data.is_a?(Hash) ? data : {}
      publishing_data = { 'client_action' => action, 'channel' => channel, 'data' => data }.reject { |_key, value| value.blank? }
      async.chat(publishing_data)
    end

    # method used to send messages to the webserver
    # checks too see if the message is a hash and if it is it will transform it to JSON and send it to the webser
    # otherwise will construct a JSON object that will have the key action with the value 'message" and the key message witth the parameter's value
    #
    # @param [Hash] message
    #
    # @return [void]
    #
    # @api private
    def chat(message)
      final_message = nil
      if message.is_a?(Hash)
        final_message = message.to_json
      else
        final_message = JSON.dump(action: 'message', message: message)
      end
      log_debug("#{@actor.class} sends JSON #{final_message}")
      connection.text final_message
    end
  end
end