require_relative './registry'
require_relative './helper'
module CelluloidPubsub
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
    include CelluloidPubsub::BaseActor

    attr_accessor :websocket, :server, :channels
    finalizer :shutdown
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
      log_debug "#{self.class} Streaming changes for #{websocket.url}"
      async.run
    end

    # the method will return true if debug is enabled
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      @server.present? && @server.alive? && @server.debug_enabled?
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
      loop do
        break if !Actor.current.alive? || @websocket.closed? || !@server.alive?
        message = try_read_websocket
        handle_websocket_message(message) if message.present?
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
      @websocket.closed? ? nil : @websocket.read
    rescue
      nil
    end

    # the method will return the reactor's class name used in debug messages
    #
    #
    # @return [Class] returns the reactor's class name used in debug messages
    #
    # @api public
    def reactor_class
      self.class
    end

    # method used to parse a JSON object into a Hash object
    #
    # @param [JSON] message
    #
    # @return [Hash]
    #
    # @api public
    def parse_json_data(message)
      JSON.parse(message)
    rescue => exception
      log_debug "#{reactor_class} could not parse #{message} because of #{exception.inspect}"
      message
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
      log_debug "#{reactor_class} read message  #{message}"
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
        log_debug "#{self.class} finds actions for  #{json_data}"
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
    #     unsubscribe_all
    #     unsubscribe_clients
    #     unsubscribe
    #     subscribe
    #     publish
    #
    #
    # @return [void]
    #
    # @api public
    def delegate_action(json_data)
      channel = json_data.fetch('channel', nil)
      case json_data['client_action']
      when 'unsubscribe_all'
        unsubscribe_all
      when 'unsubscribe_clients'
        async.unsubscribe_clients(channel)
      when 'unsubscribe'
        async.unsubscribe(channel)
      when 'subscribe'
        async.start_subscriber(channel, json_data)
      when 'publish'
        async.publish_event(channel, json_data['data'].to_json)
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
      log_debug "Trying to dispatch   to server  #{json_data}"
      @server.async.handle_dispatched_message(Actor.current, json_data)
    end

    # if the reactor has unsubscribed from all his channels will close the websocket connection,
    # otherwise will delete the channel from his channel list
    #
    # @param [String] channel  The channel that needs to be deleted from the reactor's list of subscribed channels
    #
    # @return [void]
    #
    # @api public
    def forget_channel(channel)
      if @channels.blank?
        @websocket.close
      else
        @channels.delete(channel)
      end
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
      log_debug "#{self.class} runs 'unsubscribe' method with  #{channel}"
      return unless channel.present?
      forget_channel(channel)
      @server.mutex.synchronize do
        (@server.subscribers[channel] || []).delete_if do |hash|
          hash[:reactor] == Actor.current
        end
      end
    end

    # the method will unsubscribe all  clients subscribed to a channel by closing the
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_clients(channel)
      log_debug "#{self.class} runs 'unsubscribe_clients' method with  #{channel}"
      return if channel.blank?
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
      debug "#{self.class} tries to 'shudown'"
      @websocket.close if @websocket.present? && !@websocket.closed?
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
      log_debug "#{self.class} subscribed to #{channel} with #{message}"
      @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json if @server.adapter == CelluloidPubsub::WebServer::CLASSIC_ADAPTER
    end

    # this method will return a list of all subscribers to a particular channel or a empty array
    #
    #
    # @param [String] channel The channel that will be used to fetch all subscribers from this channel
    #
    # @return [Array] returns a list of all subscribers to a particular channel or a empty array
    #
    # @api public
    def channel_subscribers(channel)
      @server.subscribers[channel] || []
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
      registry_channels = CelluloidPubsub::Registry.channels
      @channels << channel
      registry_channels << channel unless registry_channels.include?(channel)
      @server.mutex.synchronize do
        @server.subscribers[channel] = channel_subscribers(channel).push(reactor: Actor.current, message: message)
      end
    end

    #  method for publishing data to a channel
    #
    # @param [String] current_topic The Channel to which the reactor instance {CelluloidPubsub::Reactor} will publish the message to
    # @param [Object] message
    #
    # @return [void]
    #
    # @api public
    def publish_event(current_topic, message)
      return if current_topic.blank? || message.blank?
      log_debug "#{self.class} tries to publish  to #{current_topic} with #{message} into subscribers #{@server.subscribers[current_topic].inspect}"
      @server.mutex.synchronize do
        (@server.subscribers[current_topic].dup || []).pmap do |hash|
          hash[:reactor].websocket << message
        end
      end
    rescue => exception
      log_debug("could not publish message #{message} into topic #{current_topic} because of #{exception.inspect}")
    end

    # unsubscribes all actors from all channels and terminates the curent actor
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all
      log_debug "#{self.class} runs 'unsubscribe_all' method"
      CelluloidPubsub::Registry.channels.dup.pmap do |channel|
        unsubscribe_clients(channel)
      end
      log_debug 'clearing connections'
      shutdown
    end

    # unsubscribes all actors from the specified chanel
    #
    # @param [String] channel
    # @return [void]
    #
    # @api public
    def unsubscribe_from_channel(channel)
      log_debug "#{self.class} runs 'unsubscribe_from_channel' method with #{channel}"
      @server.mutex.synchronize do
        (@server.subscribers[channel].dup || []).pmap do |hash|
          reactor = hash[:reactor]
          reactor.websocket.close
          Celluloid::Actor.kill(reactor)
        end
      end
    end
  end
end
