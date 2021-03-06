# encoding: utf-8
# frozen_string_literal: true

require_relative './reactor'
require_relative './helper'
module CelluloidPubsub
  # webserver to which socket connects should connect to .
  # the server will dispatch each request into a new Reactor
  # which will handle the action based on the message
  # @attr  server_options
  #   @return [Hash] options used to configure the webserver
  #   @option server_options [String]:hostname The hostname on which the webserver runs on
  #   @option server_options [Integer] :port The port on which the webserver runs on
  #   @option server_options [String] :path The request path that the webserver accepts
  #   @option server_options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
  #
  # @attr  subscribers
  #   @return [Hash] The hostname on which the webserver runs on
  # @attr  mutex
  #   @return [Mutex] The mutex that will synchronize actions on subscribers
  # @attr  timers_mutex
  #   @return [Mutex] The mutex that will synchronize actions on registry messages
  class WebServer < Reel::Server::HTTP
    include CelluloidPubsub::BaseActor

    # The hostname on which the webserver runs on by default
    HOST = '0.0.0.0'
    # The request path that the webserver accepts by default
    PATH = '/ws'
    # The name of the default adapter
    CLASSIC_ADAPTER = 'classic'

    attr_accessor :server_options, :subscribers, :mutex, :timers_mutex

    attr_reader :reactors

    finalizer :shutdown
    trap_exit :actor_died
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
      Celluloid.boot unless Celluloid.running?
      @server_options = parse_options(options)
      @subscribers = {}
      @mutex = Mutex.new
      @timers_mutex = Mutex.new
      @shutting_down = false
      @reactors = []
      setup_celluloid_logger
      log_debug "CelluloidPubsub::WebServer example starting on #{hostname}:#{port}"
      super(hostname, port, { spy: spy, backlog: backlog }, &method(:on_connection))
    end

    # the method will  return the socket conection opened on the unused port
    #
    #
    # @return [TCPServer]  return the socket connection opened on a random port
    #
    # @api public
    def self.open_socket_on_unused_port
      return ::TCPServer.open('0.0.0.0', 0) if socket_families.key?('AF_INET')
      return ::TCPServer.open('::', 0) if socket_families.key?('AF_INET6')
      ::TCPServer.open(0)
    end

    # the method will  return the socket information available as an array
    #
    #
    # @return [Array]  return the socket information available as an array
    #
    # @api public
    def self.socket_infos
      ::Socket::getaddrinfo('localhost', nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM, 0, Socket::AI_PASSIVE)
    end

    # the method will  return the socket families avaiable
    #
    #
    # @return [Hash]  return the socket families available as keys in the hash
    #
    # @api public
    # rubocop:disable Style/ClassVars
    def self.socket_families
      @@socket_families ||= Hash[*socket_infos.map { |af, *_| af }.uniq.zip([]).flatten]
    end

    # the method get from the socket connection that is already opened the port used.
    # @see #open_socket_on_unused_port
    #
    # @return [Integer]  returns the port that can be used to issue new connection
    #
    # @api public
    def self.find_unused_port
      @@unused_port ||= begin
        socket = open_socket_on_unused_port
        port = socket.addr[1]
        socket.close
        port
      end
    end
    # rubocop:enable Style/ClassVars

    # this method is overriden from the Reel::Server::HTTP in order to set the spy to the celluloid logger
    # before the connection is accepted.
    # @see #handle_connection
    # @api public
    def run
      @spy = Celluloid.logger if spy
      async.bind_timers
      loop { async.handle_connection @server.accept }
    end

    # the method will run indefinitely and will check if are there
    # any unpublished messages that can be send to new subscribers
    #
    # @param [Boolean] run FLag to control if the server should try checking
    #   if there are any unpublished messages that need to be sent
    #
    # @return [void]
    #
    # @api public
    def bind_timers(run = false)
      try_sending_unpublished if run
      after(0.1) { bind_timers(true) }
    end

    # the method will  return true if redis can be used otherwise false
    #
    #
    # @return [Boolean]  return true if redis can be used otherwise false
    #
    # @api public
    def adapter
      @adapter ||= @server_options.fetch('adapter', CelluloidPubsub::WebServer::CLASSIC_ADAPTER)
      @adapter.present? ? @adapter : CelluloidPubsub::WebServer::CLASSIC_ADAPTER
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

    # the method will return true if debug is enabled otherwise false
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      @debug_enabled = @server_options.fetch('enable_debug', true)
      @debug_enabled == true
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
      reactors.each do |reactor|
        reactor.terminate unless actor_dead?(reactor)
      end
      terminate
    end

    # the method will return the file path of the log file where debug messages will be printed
    #
    #
    # @return [String] returns the file path of the log file where debug messages will be printed
    #
    # @api public
    def log_file_path
      @log_file_path = @server_options.fetch('log_file_path', nil)
    end

    # the method will return the log level of the logger
    #
    # @return [Integer, nil] return the log level used by the logger ( default is 1 - info)
    #
    # @api public
    def log_level
      @log_level ||= @server_options['log_level'] || ::Logger::Severity::INFO
    end

    # the method will return the hostname on which the server is running on
    #
    #
    # @return [String] returns the hostname on which the server is running on
    #
    # @api public
    def hostname
      @hostname = @server_options.fetch('hostname', CelluloidPubsub::WebServer::HOST)
    end

    # the method will return the port on which will accept connections
    #
    #
    # @return [String] returns the port on which will accept connections
    #
    # @api public
    def port
      @port ||= @server_options.fetch('port', nil) || self.class.find_unused_port
    end

    # the method will return the URL path on which will acceept connections
    #
    #
    # @return [String] returns the URL path on which will acceept connections
    #
    # @api public
    def path
      @path = @server_options.fetch('path', CelluloidPubsub::WebServer::PATH)
    end

    # the method will return true if connection to the server should be spied upon
    #
    #
    # @return [Boolean] returns true if connection to the server should be spied upon, otherwise false
    #
    # @api public
    def spy
      @spy = @server_options.fetch('spy', false)
    end

    # the method will return the number of connections allowed to the server
    #
    #
    # @return [Integer] returns the number of connections allowed to the server
    #
    # @api public
    def backlog
      @backlog = @server_options.fetch('backlog', 1024)
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
          log_debug "#{self.class} Received a WebSocket connection #{request.websocket.url}"

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

    #  returns the reactor class that will handle the connection depending if redis is enabled or not
    # @see #redis_enabled?
    #
    # @return [Class]  returns the reactor class that will handle the connection depending if redis is enabled or not
    #
    # @api public
    def reactor_class
      adapter == CelluloidPubsub::WebServer::CLASSIC_ADAPTER ? CelluloidPubsub::Reactor : "CelluloidPubsub::#{adapter.camelize}Reactor".constantize
    end

    # method will instantiate a new reactor object, will link the reactor to the current actor and will dispatch the request to the reactor
    # @see #route_websocket
    #
    # @param [Reel::WebSocket] request The request that was made to the webserver
    #
    # @return [void]
    #
    # @api public
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
      if url == path || url == '/?'
        reactor.async.work(socket, Actor.current)
      else
        log_debug "Received invalid WebSocket request for: #{url}"
        socket.close
      end
    end

    # this method will know when a client has successfully registered
    # and will write to the socket all messages that were published
    # to that channel before the actor subscribed
    #
    # @return [void]
    #
    # @api publicsCelluloidPubsub::Registry.messages
    def try_sending_unpublished
      CelluloidPubsub::Registry.messages.each_key do |channel|
        next if (clients = subscribers[channel]).blank?
        clients.dup.pmap do |hash|
          hash[:reactor].send_unpublished(channel)
        end
        clients.last[:reactor].clear_unpublished_messages(channel)
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
      final_data = message.present? && message.is_a?(Hash) ? message.to_json : data.to_json
      reactor.websocket << final_data
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
