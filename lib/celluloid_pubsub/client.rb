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
  # @!attribute client
  #   @return [Celluloid::WebSocket::Client] A websocket client that is used to chat witht the webserver
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
    attr_accessor :actor, :client, :options, :hostname, :port, :path, :channel

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
      parse_options(options)
      raise "#{self}: Please provide an actor in the options list!!!" if @actor.blank?
      raise "#{self}: Please provide an channel in the options list!!!" if @channel.blank?
      @client = Celluloid::WebSocket::Client.new("ws://#{@hostname}:#{@port}#{@path}", Actor.current)
    end

    # check the options list for values and sets default values if not found
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String] :actor The actor that made the connection
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [String] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    #
    # @return [void]
    #
    # @api public
    def parse_options(options)
      raise 'Options is not a hash' unless options.is_a?(Hash)
      @options = options.stringify_keys!
      @actor = @options.fetch('actor', nil)
      @channel = @options.fetch('channel', nil)
      @hostname = @options.fetch('hostname', CelluloidPubsub::WebServer::HOST)
      @port = @options.fetch('port', CelluloidPubsub::WebServer::PORT)
      @path = @options.fetch('path', CelluloidPubsub::WebServer::PATH)
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
      debug("#{@actor.class} tries to subscribe to channel  #{channel}") if debug_enabled?
      async.send_action('subscribe', channel)
    end

    # checks if the message has the successfull subscription action
    #
    # @param [string] message
    #
    # @return [void]
    #
    # @api public
    def succesfull_subscription?(message)
      message.present? && message['client_action'].present? && message['client_action'] == 'successful_subscription'
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
      debug("#{@actor.class} websocket connection opened") if debug_enabled?
      async.subscribe(@channel)
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
      debug("#{@actor.class} received  plain #{data}") if debug_enabled?
      message = JSON.parse(data)
      debug("#{@actor.class} received JSON  #{message}") if debug_enabled?
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
      @client.terminate
      terminate
      debug("#{@actor.class} dispatching on close  #{code} #{reason}") if debug_enabled?
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
      publishing_data = { 'client_action' => action }
      publishing_data = publishing_data.merge('channel' => channel) if channel.present?
      publishing_data = publishing_data.merge('data' => data) if data.present?
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
        debug("#{@actor.class} sends #{message.to_json}") if debug_enabled?
      else
        final_message = JSON.dump(action: 'message', message: message)
        debug("#{@actor.class} sends JSON  #{final_message}") if debug_enabled?
      end
      @client.text final_message
    end
  end
end
