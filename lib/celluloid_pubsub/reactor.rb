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
    AVAILABLE_ACTIONS = %w[unsubscribe_clients unsubscribe subscribe publish unsubscribe_all].freeze

    # The websocket connection received from the server
    # @return [Reel::WebSocket] websocket connection
    attr_accessor :websocket

    # The server instance to which this reactor is linked to
    # @return [CelluloidPubsub::Webserver] the server actor to which the reactor is connected to
    attr_accessor :server

    # The channels to which this reactor has subscribed to
    # @return [Array] array of channels to which the current reactor has subscribed to
    attr_accessor :channels

    # The same options passed to the server are available on the reactor too
    # @return [Hash] Hash with all the options passed to the server
    attr_reader :options

    finalizer :shutdown
    trap_exit :actor_died

    #  rececives a new socket connection from the server
    #  and listens for messages
    #
    # @param  [Reel::WebSocket] websocket
    #
    # @return [void]
    #
    # @api public
    def work(websocket, server)
      initialize_data(websocket, server)
      async.run
    end

    # initializes the actor
    #
    # @param  [Reel::WebSocket] websocket
    # @param  [CelluloidPubsub::WebServer] server
    #
    # @return [Celluloid::Actor] returns the actor
    #
    # @api public
    def initialize_data(websocket, server)
      @websocket = websocket
      @server = server
      @options = @server.server_options
      @channels = []
      @shutting_down = false
      setup_celluloid_logger
      log_debug "#{self.class} Streaming changes for #{websocket.url} #{websocket.class.name}"
      yield(websocket, server) if block_given?
      cell_actor
    end

    # the method will return the file path of the log file where debug messages will be printed
    #
    #
    # @return [String] returns the file path of the log file where debug messages will be printed
    #
    # @api public
    def log_file_path
      @log_file_path ||= options.fetch('log_file_path', nil)
    end

    # the method will return the log level of the logger
    #
    # @return [Integer, nil] return the log level used by the logger ( default is 1 - info)
    #
    # @api public
    def log_level
      @log_level ||= options['log_level'] || ::Logger::Severity::INFO
    end

    # the method will return options needed when configuring an adapter
    # @see celluloid_pubsub_redis_adapter for more information
    #
    # @return [Hash] returns options needed by the adapter
    #
    # @api public
    def adapter_options
      @adapter_options ||= options['adapter_options'] || {}
    end

    # the method will return true if the actor is shutting down
    #
    #
    # @return [Boolean] returns true if the actor is shutting down
    #
    # @api public
    def shutting_down?
      @shutting_down == true
    end

    # the method will return true if debug is enabled
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      @debug_enabled = options.fetch('enable_debug', false)
      @debug_enabled == true
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
        break if shutting_down? || actor_dead?(Actor.current) || @websocket.closed? || actor_dead?(@server)
        message = try_read_websocket
        handle_websocket_message(message) if message.present?
      end
    end
    # :nocov:

    # will try to read the message from the websocket
    # and if it fails will log the exception if debug is enabled
    #
    # @return [void]
    #
    # @api public
    #
    def try_read_websocket
      @websocket.closed? ? nil : @websocket.read
    rescue StandardError
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
      log_debug "#{reactor_class} received #{message}"
      JSON.parse(message)
    rescue StandardError => e
      log_debug "#{reactor_class} could not parse #{message} because of #{e.inspect}"
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
      data = json_data.is_a?(Hash) ? json_data.stringify_keys : {}
      if CelluloidPubsub::Reactor::AVAILABLE_ACTIONS.include?(data['client_action'].to_s)
        log_debug "#{self.class} finds actions for  #{json_data}"
        delegate_action(data) if data['client_action'].present?
      else
        handle_unknown_action(data['channel'], json_data)
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
      async.send(json_data['client_action'], json_data['channel'], json_data)
    end

    # the method will delegate the message to the server in an asyncronous way by sending the current actor and the message
    # @see CelluloidPubsub::WebServer#handle_dispatched_message
    #
    # @param [Hash] json_data
    #
    # @return [void]
    #
    # @api public
    def handle_unknown_action(channel, json_data)
      log_debug "Trying to dispatch   to server  #{json_data} on channel #{channel}"
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
    def unsubscribe(channel, _json_data)
      log_debug "#{self.class} runs 'unsubscribe' method with  #{channel}"
      return unless channel.present?
      forget_channel(channel)
      delete_server_subscribers(channel)
    end

    # the method will delete the reactor from the channel list on the server
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def delete_server_subscribers(channel)
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
    def unsubscribe_clients(channel, _json_data)
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
      @shutting_down = true
      log_debug "#{self.class} tries to 'shutdown'"
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
    def subscribe(channel, message)
      return unless channel.present?
      add_subscriber_to_channel(channel, message)
      log_debug "#{self.class} subscribed to #{channel} with #{message}"
      @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json if @server.adapter == CelluloidPubsub::WebServer::CLASSIC_ADAPTER
    end

    # this method will write to the socket all messages that were published
    # to that channel before the actor subscribed
    #
    # @param [String] channel
    # @return [void]
    #
    # @api public
    def send_unpublished(channel)
      return if (messages = unpublished_messages(channel)).blank?
      messages.each do |msg|
        @websocket << msg.to_json
      end
    end

    # the method clears all the messages left unpublished in a channel
    #
    # @param [String] channel
    #
    # @return [void]
    #
    # @api public
    def clear_unpublished_messages(channel)
      CelluloidPubsub::Registry.messages[channel] = []
    end

    # the method will return a list of all unpublished messages in a channel
    #
    # @param [String] channel
    #
    # @return [Array] the list of messages that were not published
    #
    # @api public
    def unpublished_messages(channel)
      (messages = CelluloidPubsub::Registry.messages[channel]).present? ? messages : []
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
    # @param [Object] json_data The additional data that contains the message that needs to be sent
    #
    # @return [void]
    #
    # @api public
    def publish(current_topic, json_data)
      message = json_data['data'].to_json
      return if current_topic.blank? || message.blank?
      server_publish_event(current_topic, message)
    rescue StandardError => e
      log_debug("could not publish message #{message} into topic #{current_topic} because of #{e.inspect}")
    end

    # the method will publish to all subsribers of a channel a message
    #
    # @param [String] current_topic
    # @param [#to_s] message
    #
    # @return [void]
    #
    # @api public
    def server_publish_event(current_topic, message)
      if (subscribers = @server.subscribers[current_topic]).present?
        subscribers.dup.pmap do |hash|
          hash[:reactor].websocket << message
        end
      else
        save_unpublished_message(current_topic, message)
      end
    end

    # the method save the message for a specific channel if there are no subscribers
    #
    # @param [String] current_topic
    # @param [#to_s] message
    #
    # @return [void]
    #
    # @api public
    def save_unpublished_message(current_topic, message)
      @server.timers_mutex.synchronize do
        (CelluloidPubsub::Registry.messages[current_topic] ||= []) << message
      end
    end

    # unsubscribes all actors from all channels and terminates the current actor
    #
    # @param [String] _channel NOT USED - needed to maintain compatibility with the other methods
    # @param [Object] json_data NOT USED - needed to maintain compatibility with the other methods
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all(_channel, json_data)
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
        (@server.subscribers[channel] || []).dup.pmap do |hash|
          reactor = hash[:reactor]
          reactor.websocket.close
          Celluloid::Actor.kill(reactor)
        end
      end
    end

    # method called when the actor is exiting
    #
    # @param [actor] actor - the current actor
    # @param [Hash] reason - the reason it crashed
    #
    # @return [void]
    #
    # @api public
    def actor_died(actor, reason)
      @shutting_down = true
      log_debug "Oh no! #{actor.inspect} has died because of a #{reason.class}"
    end
  end
end
