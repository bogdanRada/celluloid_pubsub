require_relative './registry'
module CelluloidPubsub
  # rubocop:disable ClassLength
  # The reactor handles new connections. Based on what the client sends it either subscribes to a channel
  # or will publish to a channel or just dispatch to the server if command is neither subscribe, publish or unsubscribe
  #
  # @!attribute websocket
  #   @return [Reel::WebSocket] websocket connection
  #
  # @!attribute server
  #   @return [CelluloidPubsub::Webserver] the server actor to which the reactor is connected to
  #
  # @!attribute channels
  #   @return [Array] array of channels to which the current reactor has subscribed to
  class Reactor
    include Celluloid
    include Celluloid::IO
    include Celluloid::Logger

    attr_accessor :websocket, :server, :channels

    #  rececives a new socket connection from the server
    #  and listens for messages
    #
    # @param  [Reel::WebSocket] websocket
    #
    # @return [void]
    #
    # @api public
    def work(websocket, server)
      @server = server
      @channels = []
      @websocket = websocket
      info "#{self.class} Streaming changes for #{websocket.url}" 
      async.run
    end

    # reads from the socket the message
    # and dispatches it to the handle_websocket_message method
    # @see #handle_websocket_message
    #
    # @return [void]
    #
    # @api public
    #
    # :nocov:
    def run
      while Actor.current.alive? && !@websocket.closed? && message = try_read_websocket
        handle_websocket_message(message)
      end
    end

    # will try to read the message from the websocket
    # and if it fails will log the exception if debug is enabled
    #
    # @return [void]
    #
    # @api public
    #
    # :nocov:
    def try_read_websocket
      message = nil
      begin
        message = @websocket.read
      rescue => e
        debug(e)
      end
      message
    end

    # :nocov:

    # method used to parse a JSON object into a Hash object
    #
    # @param [JSON] message
    #
    # @return [Hash]
    #
    # @api public
    def parse_json_data(message)
      debug "#{self.class} read message  #{message}" if @server.debug_enabled?
      json_data = nil
      begin
        json_data = JSON.parse(message)
      rescue => e
        debug "#{self.class} could not parse #{message} because of #{e.inspect}" if @server.debug_enabled?
        # do nothing
      end
      json_data = message if json_data.nil?
      json_data
    end

    # method that handles the message received from the websocket connection
    # first will try to parse the message {#parse_json_data}  and then it will dispatch
    # it to another method that will decide depending the message what action
    # should the reactor take {#handle_parsed_websocket_message}
    #
    # @see #parse_json_data
    # @see #handle_parsed_websocket_message
    #
    # @param [JSON] message
    #
    # @return [void]
    #
    # @api public
    def handle_websocket_message(message)
      json_data = parse_json_data(message)
      handle_parsed_websocket_message(json_data)
    end

    # method that checks if the data is a Hash
    #
    # if the data is a hash then will stringify the keys and will call the method {#delegate_action}
    # that will handle the message, otherwise will call the method {#handle_unknown_action}
    #
    # @see #delegate_action
    # @see #handle_unknown_action
    #
    # @param [Hash] json_data
    #
    # @return [void]
    #
    # @api public
    def handle_parsed_websocket_message(json_data)
      if json_data.is_a?(Hash)
        json_data = json_data.stringify_keys
        debug "#{self.class} finds actions for  #{json_data}" if @server.debug_enabled?
        delegate_action(json_data) if json_data['client_action'].present?
      else
        handle_unknown_action(json_data)
      end
    end

    # method that checks if the data is a Hash
    #
    # if the data is a hash then will stringify the keys and will call the method {#delegate_action}
    # that will handle the message, otherwise will call the method {#handle_unknown_action}
    #
    # @see #delegate_action
    # @see #handle_unknown_action
    #
    # @param [Hash] json_data
    # @option json_data [String] :client_action The action based on which the reactor will decide what action should make
    #
    #   Possible values are:
    #     unsubscribe_client
    #     unsubscribe
    #     subscribe
    #     publish
    #
    #
    # @return [void]
    #
    # @api public
    def delegate_action(json_data)
      case json_data['client_action']
      when 'unsubscribe_all'
        unsubscribe_all
      when 'unsubscribe_clients'
        async.unsubscribe_clients(json_data['channel'])
      when 'unsubscribe'
        async.unsubscribe(json_data['channel'])
      when 'subscribe'
        async.start_subscriber(json_data['channel'], json_data)
      when 'publish'
        @server.publish_event(json_data['channel'], json_data['data'].to_json)
      else
        handle_unknown_action(json_data)
      end
    end

    # the method will delegate the message to the server in an asyncronous way by sending the current actor and the message
    # @see {CelluloidPubsub::WebServer#handle_dispatched_message}
    #
    # @param [Hash] json_data
    #
    # @return [void]
    #
    # @api public
    def handle_unknown_action(json_data)
      debug "Trying to dispatch   to server  #{json_data}" if @server.debug_enabled?
      @server.async.handle_dispatched_message(Actor.current, json_data)
    end

    # the method will unsubscribe a client by closing the websocket connection if has unscribed from all channels
    # and deleting the reactor from the channel list on the server
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def unsubscribe(channel)
      debug "#{self.class} runs 'unsubscribe' method with  #{channel}" if @server.debug_enabled?
      return unless channel.present?
      @channels.delete(channel) unless @channels.blank?
      @websocket.close if @channels.blank?
      @server.subscribers[channel].delete_if do |hash|
        hash[:reactor] == Actor.current
      end if @server.subscribers[channel].present?
    end

    # the method will unsubscribe all  clients subscribed to a channel by closing the
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_clients(channel)
      debug "#{self.class} runs 'unsubscribe_clients' method with  #{channel}" if @server.debug_enabled?
      return if channel.blank? || @server.subscribers[channel].blank?
      unsubscribe_from_channel(channel)
      @server.subscribers[channel] = []
    end

    # the method will terminate the current actor
    #
    #
    # @return [void]
    #
    # @api public
    def shutdown
      debug "#{self.class} tries to 'shudown'" if @server.debug_enabled?
      terminate
    end

    # this method will add the current actor to the list of the subscribers {#add_subscriber_to_channel}
    # and will write to the socket a message for succesful subscription
    #
    # @see #add_subscriber_to_channel
    #
    # @param [String] channel
    # @param [Object] message
    #
    # @return [void]
    #
    # @api public
    def start_subscriber(channel, message)
      return unless channel.present?
      add_subscriber_to_channel(channel, message)
      debug "#{self.class} subscribed to #{channel} with #{message}" if @server.debug_enabled?
      @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json unless @server.redis_enabled?
    end

    # adds the curent actor the list of the subscribers for a particular channel
    # and registers the new channel
    #
    # @param [String] channel
    # @param [Object] message
    #
    # @return [void]
    #
    # @api public
    def add_subscriber_to_channel(channel, message)
      @channels << channel
      CelluloidPubsub::Registry.channels << channel unless CelluloidPubsub::Registry.channels.include?(channel)
      @server.subscribers[channel] ||= []
      @server.subscribers[channel] << { reactor: Actor.current, message: message }

    end

    # unsubscribes all actors from all channels and terminates the curent actor
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all
      debug "#{self.class} runs 'unsubscribe_all' method" if @server.debug_enabled?
      CelluloidPubsub::Registry.channels.map do |channel|
        unsubscribe_from_channel(channel)
        @server.subscribers[channel] = []
      end

      info 'clearing connections' if @server.debug_enabled?
      shutdown
    end

    # unsubscribes all actors from the specified chanel
    #
    # @param [String] channel
    # @return [void]
    #
    # @api public
    def unsubscribe_from_channel(channel)
      debug "#{self.class} runs 'unsubscribe_from_channel' method with #{channel}" if @server.debug_enabled?
      return if @server.subscribers[channel].blank?
      @server.subscribers[channel].each do |hash|
        hash[:reactor].websocket.close
        Celluloid::Actor.kill(hash[:reactor])
      end
    end
  end
end
