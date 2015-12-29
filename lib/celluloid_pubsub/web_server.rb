require_relative './reactor'
require_relative './helper'
module CelluloidPubsub
  # webserver to which socket connects should connect to .
  # the server will dispatch each request into a new Reactor
  # which will handle the action based on the message
  # @!attribute options
  #   @return [Hash] options used to configure the webserver
  #   @option options [String]:hostname The hostname on which the webserver runs on
  #   @option options [Integer] :port The port on which the webserver runs on
  #   @option options [String] :path The request path that the webserver accepts
  #   @option options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
  #
  # @!attribute subscribers
  #   @return [Hash] The hostname on which the webserver runs on
  #
  # @!attribute backlog
  #   @return [Integer] Determines how many connections can be used
  #   Defaults to 1024
  #
  # @!attribute hostname
  #   @return [String] The hostname on which the webserver runs on
  #
  # @!attribute port
  #  @return [String] The port on which the webserver runs on
  #
  # @!attribute path
  #   @return [String] The hostname on which the webserver runs on
  #
  # @!attribute spy
  #   @return [Boolean] Enable this only if you want to enable debugging for the webserver
  class WebServer < Reel::Server::HTTP
    include Celluloid::Logger
    include CelluloidPubsub::Helper

    # The hostname on which the webserver runs on by default
    HOST = '0.0.0.0'
    # The port on which the webserver runs on by default
    PORT = 1234
    # The request path that the webserver accepts by default
    PATH = '/ws'

    attr_accessor :options, :subscribers, :backlog, :hostname, :port, :path, :spy, :use_redis, :debug_enabled
    finalizer :shutdown
    #  receives a list of options that are used to configure the webserver
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [Integer] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    # @option options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
    #
    # @return [void]
    #
    # @api public
    #
    # :nocov:
    def initialize(options = {})
      @options = parse_options(options)
      log_debug @options
      @subscribers = {}
      log_debug "CelluloidPubsub::WebServer example starting on #{hostname}:#{port}"
      super(hostname, port, { spy: spy, backlog: backlog }, &method(:on_connection))
    end

    def use_redis
      @use_redis ||= @options.fetch('use_redis', false)
    end

    def debug_enabled?
      @debug_enabled = @options.fetch('enable_debug', false)
      @debug_enabled == true
    end

    # the method will terminate the current actor
    #
    #
    # @return [void]
    #
    # @api public
    def shutdown
      debug "#{self.class} tries to 'shudown'"
      terminate
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

    def spy
      @spy ||= @options.fetch('spy', false)
    end

    def backlog
      @backlog = @options.fetch('backlog', 1024)
    end

    # :nocov:

    def redis_enabled?
      use_redis.to_s.downcase == 'true'
    end

    #  method for publishing data to a channel
    #
    # @param [String] current_topic The Channel to which the reactor instance {CelluloidPubsub::Rector} will publish the message to
    # @param [Object] message
    #
    # @return [void]
    #
    # @api public
    def publish_event(current_topic, message)
      if redis_enabled?
        publish_redis_event(current_topic, message)
      else
        publish_clasic_event(current_topic, message)
      end
    rescue => exception
      log_debug("could not publish message #{message} into topic #{current_topic} because of #{exception.inspect}")
    end

    def publish_redis_event(topic, data)
      return if !redis_enabled? || topic.blank? || data.blank?
      CelluloidPubsub::Redis.connect do |connection|
        connection.publish(topic, data)
      end
    end

    def publish_clasic_event(channel, data)
      channel_subscribers = @subscribers[channel]
      return if channel.blank? || data.blank?
      channel_subscribers.each do |hash|
        hash[:reactor].websocket << data
      end if channel_subscribers.present?
    end

    #  callback that will execute when receiving new conections
    # If the connections is a websocket will call method {#route_websocket}
    # and if the connection is HTTP will call method {#route_request}
    # For websocket connections , the connection is detached from the server and dispatched to another actor
    #
    # @see #route_websocket
    # @see #route_request
    #
    # @param [Reel::WebSocket] connection The connection that was made to the webserver
    #
    # @return [void]
    #
    # @api public
    def on_connection(connection)
      while request = connection.request
        if request.websocket?
          log_debug "#{self.class} Received a WebSocket connection"

          # We're going to hand off this connection to another actor (Writer/Reader)
          # However, initially Reel::Connections are "attached" to the
          # Reel::Server::HTTP actor, meaning that the server manages the connection
          # lifecycle (e.g. error handling) for us.
          #
          # If we want to hand this connection off to another actor, we first
          # need to detach it from the Reel::Server (in this case, Reel::Server::HTTP)
          connection.detach
          dispatch_websocket_request(request)
          return
        else
          route_request connection, request
        end
      end
    end

    def reactor_class
      redis_enabled? ? CelluloidPubsub::RedisReactor : CelluloidPubsub::Reactor
    end

    def dispatch_websocket_request(request)
      reactor = reactor_class.new
      Actor.current.link reactor
      route_websocket(reactor, request.websocket)
    end

    #  HTTP connections are not accepted so this method will show 404 message "Not Found"
    #
    # @param [Reel::WebSocket] connection The HTTP connection that was received
    # @param [Reel::Request] request The request that was made to the webserver and contains the type , the url, and the parameters
    #
    # @return [void]
    #
    # @api public
    def route_request(connection, request)
      log_debug "404 Not Found: #{request.path}"
      connection.respond :not_found, 'Not found'
    end

    #  If the socket url matches with the one accepted by the server, it will dispatch the socket connection to a new reactor {CelluloidPubsub::Reactor#work}
    # The new actor is linked to the webserver
    #
    # @see CelluloidPubsub::Reactor#work
    #
    #  @param [Reel::WebSocket] socket The  web socket connection that was received
    #
    # @return [void]
    #
    # @api public
    def route_websocket(reactor, socket)
      url = socket.url
      if url == path
        reactor.async.work(socket, Actor.current)
      else
        log_debug "Received invalid WebSocket request for: #{url}"
        socket.close
      end
    end

    # If the message can be parsed into a Hash it will respond to the reactor's websocket connection with the same message in JSON format
    # otherwise will try send the message how it is and escaped into JSON format
    #
    # @param [CelluloidPubsub::Reactor] reactor The  reactor that received an unhandled message
    # @param [Object] data The message that the reactor could not handle
    #
    # @return [void]
    #
    # @api public
    def handle_dispatched_message(reactor, data)
      log_debug "#{self.class} trying to dispatch message  #{data.inspect}"
      message = reactor.parse_json_data(data)
      if message.present? && message.is_a?(Hash)
        final_data = message.to_json
      else
        final_data data.to_json
      end
      reactor.websocket << final_data
    end
  end
end
