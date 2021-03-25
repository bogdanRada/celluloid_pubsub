# encoding: utf-8
# frozen_string_literal: true

require_relative './helper'
module CelluloidPubsub
  # worker that subscribes to a channel or publishes to a channel
  # if it used to subscribe to a channel the worker will dispatch the messages to the actor that made the
  # connection in the first place.
  #
  # @!attribute actor
  #   @return [Celluloid::Actor] actor to which callbacks will be delegated to
  #
  # @!attribute options
  #   @return [Hash] the options that can be used to connect to webser and send additional data
  #
  # @!attribute channel
  #   @return [String] The channel to which the client will subscribe to
  class Client
    include CelluloidPubsub::BaseActor

    # The actor that made the connection
    # @return [Celluloid::Actor] actor to which callbacks will be delegated to
    attr_accessor :actor

    #  options that can be used to connect to webser and send additional data
    # @return [Hash] the options that can be used to connect to webser and send additional data
    attr_accessor :options

    # The channel to which the client will subscribe to once the connection is open
    # @return [String] The channel to which the client will subscribe to
    attr_accessor :channel

    finalizer :shutdown
    trap_exit :actor_died
    #  receives a list of options that are used to connect to the webserver and an actor to which the callbacks are delegated to
    #  when receiving messages from a channel
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String] :actor The actor that made the connection
    # @option options [String] :channel The channel to which the client will subscribe to once the connection is open
    # @option options [String] :log_file_path The path to the log file where debug messages will be printed, otherwise will use STDOUT
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [String] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    #
    # @return [void]
    #
    # @api public
    def initialize(options)
      @options = options.stringify_keys!
      @actor ||= @options.fetch('actor', nil)
      @channel ||= @options.fetch('channel', nil)
      @shutting_down = false
      raise "#{self}: Please provide an actor in the options list!!!" if @actor.blank?
      setup_celluloid_logger
      log_debug "#{@actor.class} starting on #{hostname}:#{port}"
      supervise_actors
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

    # the method will return the path to the log file where debug messages will be printed
    #
    # @return [String, nil] return the path to the log file where debug messages will be printed
    #
    # @api public
    def log_file_path
      @log_file_path ||= @options.fetch('log_file_path', nil)
    end

    # the method will return the log level of the logger
    #
    # @return [Integer, nil] return the log level used by the logger ( default is 1 - info)
    #
    # @api public
    def log_level
      @log_level ||= @options['log_level'] || ::Logger::Severity::INFO
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

    # the method will return the hostname of the server
    #
    #
    # @return [String] the hostname where the server runs on
    #
    # @api public
    def hostname
      @hostname ||= @options.fetch('hostname', CelluloidPubsub::WebServer::HOST)
    end

    # the method will return the port on which the server accepts connections
    #
    #
    # @return [String] the port on which the server accepts connections
    #
    # @api public
    def port
      @port ||= @options.fetch('port', nil) || CelluloidPubsub::WebServer.find_unused_port
    end

    # the method will return the path of the URL on which the servers acccepts the connection
    #
    #
    # @return [String] the URL path that the server is mounted on
    #
    # @api public
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
      @shutting_down = true
      log_debug "#{self.class} tries to 'shutdown'"
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
    def subscribe(channel, data = {})
      log_debug("#{@actor.class} tries to subscribe to channel  #{channel}")
      async.send_action('subscribe', channel, data)
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
      async.subscribe(@channel) if @channel.present?
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
      if @actor.respond_to?(:async)
        @actor.async.on_message(message)
      else
        @actor.on_message(message)
      end
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
      log_debug("#{self.class} dispatching on close  #{code} #{reason}")
      if @actor.respond_to?(:async)
        @actor.async.on_close(code, reason)
      else
        @actor.on_close(code, reason)
      end
    ensure
      connection.terminate unless actor_dead?(connection)
      terminate
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
      final_message = message.is_a?(Hash) ? message.to_json : JSON.dump(action: 'message', message: message)
      log_debug("#{@actor.class} sends JSON #{final_message}")
      connection.text final_message
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
