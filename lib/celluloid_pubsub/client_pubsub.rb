module CelluloidPubsub
  # class used to make a new connection in order to subscribe or publish to a channel
  class Client
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
    class PubSubWorker
      include Celluloid
      include Celluloid::Logger
      attr_accessor :actor, :connect_blk, :client, :options, :hostname, :port, :path

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
      def initialize(options, &connect_blk)
        parse_options(options)
        raise "#{self}: Please provide an actor in the options list!!!" if @actor.blank?
        @connect_blk = connect_blk
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
        CelluloidPubsub::WebServer.debug_enabled?
      end

      # subscribes to a channel . need to be used inside the connect block passed to the actor
      #
      # @param [string] channel
      #
      # @return [void]
      #
      # @api public
      def subscribe(channel)
        subscription_data = { 'client_action' => 'subscribe', 'channel' => channel }
        debug("#{self.class} tries to subscribe  #{subscription_data}") if debug_enabled?
        async.chat(subscription_data)
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
        publishing_data = { 'client_action' => 'publish', 'channel' => channel, 'data' => data }
        debug(" #{self.class}  publishl to #{channel} message:  #{publishing_data}") if debug_enabled?
        async.chat(publishing_data)
      end

      #  callback executes after connection is opened and delegates action to actor
      #
      # @return [void]
      #
      # @api public
      def on_open
        debug("#{self.class} websocket connection opened") if debug_enabled?
        @connect_blk.call Actor.current
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
        debug("#{self.class} received  plain #{data}") if debug_enabled?
        message = JSON.parse(data)
        debug("#{self.class} received JSON  #{message}") if debug_enabled?
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
        debug("#{self.class} dispatching on close  #{code} #{reason}") if debug_enabled?
        @actor.async.on_close(code, reason)
      end

    private

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
          debug("#{self.class} sends #{message.to_json}") if debug_enabled?
          final_message = message.to_json
        else
          text_messsage = JSON.dump(action: 'message', message: message)
          debug("#{self.class} sends JSON  #{text_messsage}") if debug_enabled?
          final_message = text_messsage
        end
        @client.text final_message
      end
    end

    # method used to make a new connection to the webserver
    # after the connection is opened it will execute the block that is passed as argument
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String] :actor The actor that made the connection
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [String] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    #
    # @param [Proc] connect_blk Block  that will execute after the connection is opened
    #
    # @return [CelluloidPubsub::Client::PubSubWorker]
    #
    # @api public
    def self.connect(options = {}, &connect_blk)
      CelluloidPubsub::Client::PubSubWorker.new(options, &connect_blk)
    end
  end
end
