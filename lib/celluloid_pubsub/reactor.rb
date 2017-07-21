# encoding: utf-8
# frozen_string_literal: true
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

    # available actions that can be delegated
    AVAILABLE_ACTIONS = %w(unsubscribe_clients unsubscribe subscribe publish unsubscribe_all).freeze

    # The server instance to which this reactor is linked to
    # @return [CelluloidPubsub::Webserver] the server actor to which the reactor is connected to
    attr_accessor :server

    # The channels to which this reactor has subscribed to
    # @return [Array] array of channels to which the current reactor has subscribed to
    attr_accessor :channels

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
      log_debug "#{self.class} Streaming changes for #{websocket.url}"
      async.run(websocket)
    end

    # the method will return true if debug is enabled
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      !@server.dead? && @server.debug_enabled?
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
    def run(websocket)
      loop do
        break if Actor.current.dead? || @server.dead?
        message = try_read_websocket(websocket)
        handle_websocket_message(websocket, message) if message.present?
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
    def try_read_websocket(websocket)
      websocket.closed? ? nil : websocket.read
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
    def handle_websocket_message(websocket, message)
      log_debug "#{reactor_class} read message  #{message}"
      json_data = parse_json_data(message)
      handle_parsed_websocket_message(websocket, json_data)
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
    def handle_parsed_websocket_message(websocket, json_data)
      data =  json_data.is_a?(Hash) ? json_data.stringify_keys : {}
      if CelluloidPubsub::Reactor::AVAILABLE_ACTIONS.include?(data['client_action'].to_s)
        log_debug "#{self.class} finds actions for  #{json_data}"
        delegate_action(websocket, data) if data['client_action'].present?
      else
        handle_unknown_action(websocket, data['channel'], json_data)
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
    def delegate_action(websocket, json_data)
      async.send(json_data['client_action'], websocket, json_data['channel'], json_data)
    end
    
    # the method will delegate the message to the server in an asyncronous way by sending the current actor and the message
    # @see {CelluloidPubsub::WebServer#handle_dispatched_message}
    #
    # @param [Hash] json_data
    #
    # @return [void]
    #
    # @api public
    def handle_unknown_action(websocket, channel, json_data)
      log_debug "Trying to dispatch   to server  #{json_data} on channel #{channel}"
      @server.async.handle_dispatched_message(websocket, Actor.current, json_data)
    end

    # if the reactor has unsubscribed from all his channels will close the websocket connection,
    # otherwise will delete the channel from his channel list
    #
    # @param [String] channel  The channel that needs to be deleted from the reactor's list of subscribed channels
    #
    # @return [void]
    #
    # @api public
    def forget_channel(websocket, channel)
      if @channels.blank?
        websocket.close
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
    def unsubscribe(websocket, channel, _json_data)
      log_debug "#{self.class} runs 'unsubscribe' method with  #{channel}"
      return unless channel.present?
      forget_channel(websocket, channel)
      delete_server_subscribers(websocket, channel)
    end

    # the method will delete the reactor from the channel list on the server
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def delete_server_subscribers(websocket, channel)
      @server.mutex.synchronize do
        (@server.subscribers[channel] || []).delete_if do |hash|
          hash[:socket] == websocket
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
    def unsubscribe_clients(websocket, channel, _json_data)
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
    def subscribe(websocket, channel, message)
      return unless channel.present?
      add_subscriber_to_channel(websocket, channel, message)
      log_debug "#{self.class} subscribed to #{channel} with #{message}"
      websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json if @server.adapter == CelluloidPubsub::WebServer::CLASSIC_ADAPTER
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
    def add_subscriber_to_channel(websocket, channel, message)
      registry_channels = CelluloidPubsub::Registry.channels
      @channels << channel
      registry_channels << channel unless registry_channels.include?(channel)
      @server.mutex.synchronize do
        @server.subscribers[channel] = channel_subscribers(channel).push(socket: websocket, message: message)
      end
    end

    #  method for publishing data to a channel
    #
    # @param [String] current_topic The Channel to which the reactor instance {CelluloidPubsub::Reactor} will publish the message to
    # @param [Object] json_data The additional data that contains the message that needs to be sent
    #
    # @return [void]
    #
    # @api public
    def publish(websocket, current_topic, json_data)
      message = json_data['data'].to_json
      return if current_topic.blank? || message.blank?
      server_pusblish_event(current_topic, message)
    rescue => exception
      log_debug("could not publish message #{message} into topic #{current_topic} because of #{exception.inspect}")
    end

    # the method will publish to all subsribers of a channel a message
    #
    # @param [String] current_topic
    # @param [#to_s] message
    #
    # @return [void]
    #
    # @api public
    def server_pusblish_event(current_topic, message)
      @server.mutex.synchronize do
        (@server.subscribers[current_topic].dup || []).pmap do |hash|
          hash[:socket] << message
        end
      end
    end

    # unsubscribes all actors from all channels and terminates the curent actor
    #
    # @param [String] _channel NOT USED - needed to maintain compatibility with the other methods
    # @param [Object] _json_data NOT USED - needed to maintain compatibility with the other methods
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all(websocket, _channel, json_data)
      log_debug "#{self.class} runs 'unsubscribe_all' method"
      CelluloidPubsub::Registry.channels.dup.pmap do |channel|
        unsubscribe_clients(channel, json_data)
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
      server_kill_reactors(channel)
    end

    # kills all reactors registered on a channel and closes their websocket connection
    #
    # @param [String] channel
    # @return [void]
    #
    # @api public
    def server_kill_reactors(channel)
      @server.mutex.synchronize do
        (@server.subscribers[channel].dup || []).pmap do |hash|
          socket = hash[:socket]
          socket.close if socket.present?
        end
      end
    end
  end
end
