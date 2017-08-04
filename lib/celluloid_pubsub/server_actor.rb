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
  module ServerActor
    include CelluloidPubsub::BaseActor



    def self.included(base)
      base.send(:include, CelluloidPubsub::BaseActor)
    end

    attr_accessor :server_options, :subscribers, :mutex, :server_options, :app
    attr_reader :worker_supervisor, :workers
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
    def initialize_server(app, options = {})
      Celluloid.boot unless Celluloid.running?
      @server_options = parse_options(options)
      @subscribers = {}
      @mutex = Mutex.new
      setup_celluloid_logger
      @app = app
      raise ArgumentError, "no host given" unless hostname
      raise ArgumentError, "no port given" unless port

      info  "A Reel good HTTP server! (Codename \"#{::Reel::CODENAME}\")"
      info "Listening on http://#{hostname}:#{port}"
      yield if block_given?
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
    # rubocop:disable ClassVars
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
    # rubocop:enable ClassVars

    # this method is overriden from the Reel::Server::HTTP in order to set the spy to the celluloid logger
    # before the connection is accepted.
    # @see #handle_connection
    # @api public
    def run
      @spy = Celluloid.logger if spy
      loop { async.handle_connection @server.accept }
    end

    # the method will  return true if redis can be used otherwise false
    #
    #
    # @return [Boolean]  return true if redis can be used otherwise false
    #
    # @api public
    def adapter
      @adapter ||= @server_options.delete(:adapter) ||  CelluloidPubsub.config.adapter
      @adapter.present? ? @adapter : CelluloidPubsub.config.adapter
    end


    def http_adapter
      @http_adapter ||= @server_options.delete(:http_adapter) ||  CelluloidPubsub.config.http_adapter
      @http_adapter.present? ? @http_adapter : CelluloidPubsub.config.http_adapter
    end
    # the method will return true if debug is enabled otherwise false
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      @debug_enabled = @server_options.delete(:quiet) || CelluloidPubsub.config.quiet
      @debug_enabled == false
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

    # the method will return the file path of the log file where debug messages will be printed
    #
    #
    # @return [String] returns the file path of the log file where debug messages will be printed
    #
    # @api public
    def log_file_path
      @log_file_path = @server_options.delete(:log_file_path) || CelluloidPubsub.config.log_file_path
    end

    # the method will return the hostname on which the server is running on
    #
    #
    # @return [String] returns the hostname on which the server is running on
    #
    # @api public
    def hostname
      @hostname = @server_options.delete(:host) || CelluloidPubsub.config.host
    end

    # the method will return the port on which will accept connections
    #
    #
    # @return [String] returns the port on which will accept connections
    #
    # @api public
    def port
      @port ||= @server_options.delete(:port) || CelluloidPubsub.config.port || CelluloidPubsub::ServerActor.find_unused_port
    end

    # the method will return the URL path on which will acceept connections
    #
    #
    # @return [String] returns the URL path on which will acceept connections
    #
    # @api public
    def path
      @path = @server_options.delete('path') || CelluloidPubsub.config.path
    end

    # the method will return true if connection to the server should be spied upon
    #
    #
    # @return [Boolean] returns true if connection to the server should be spied upon, otherwise false
    #
    # @api public
    def spy
      @spy = @server_options.delete(:spy) || CelluloidPubsub.config.spy
    end

    # the method will return the number of connections allowed to the server
    #
    #
    # @return [Integer] returns the number of connections allowed to the server
    #
    # @api public
    def backlog
      @backlog = @server_options.delete(:backlog) || CelluloidPubsub.config.backlog
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
      connection.detach
      connection.each_request do  |request|
        if request.websocket?
          log_debug "#{self.class} Received a WebSocket connection"

          # We're going to hand off this connection to another actor (Writer/Reader)
          # However, initially Reel::Connections are "attached" to the
          # Reel::Server::HTTP actor, meaning that the server manages the connection
          # lifecycle (e.g. error handling) for us.
          #
          # If we want to hand this connection off to another actor, we first
          # need to detach it from the Reel::Server (in this case, Reel::Server::HTTP)
          dispatch_websocket_request(request)
          return
        else
          route_request(request)
        end
      end
    end

    def route_request(request)
      log_debug "#{self.class} Received a HTTP connection #{request.url}"

      # We're going to hand off this connection to another actor (Writer/Reader)
      # However, initially Reel::Connections are "attached" to the
      # Reel::Server::HTTP actor, meaning that the server manages the connection
      # lifecycle (e.g. error handling) for us.
      #
      # If we want to hand this connection off to another actor, we first
      # need to detach it from the Reel::Server (in this case, Reel::Server::HTTP)
      dispatch_http_request(request)
      return
    end

    #  returns the reactor class that will handle the connection depending if redis is enabled or not
    # @see #redis_enabled?
    #
    # @return [Class]  returns the reactor class that will handle the connection depending if redis is enabled or not
    #
    # @api public
    def reactor_class
      adapter == 'classic' ? CelluloidPubsub::Reactor : "CelluloidPubsub::#{adapter.camelize}Reactor".constantize
    end

    #  returns the reactor class that will handle the connection depending if redis is enabled or not
    # @see #redis_enabled?
    #
    # @return [Class]  returns the reactor class that will handle the connection depending if redis is enabled or not
    #
    # @api public
    def http_reactor_class
      http_adapter == 'classic' ? CelluloidPubsub::HttpReactor : "CelluloidPubsub::#{http_adapter.camelize}HttpReactor".constantize
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

    def dispatch_http_request(request)
      if !defined?(@http_reactor)
        @http_reactor ||= http_reactor_class.new
        Actor.current.link @http_reactor
      end
      route_http_request(@http_reactor, request)
    end

    def route_http_request(reactor, request)
      reactor.work(request, Actor.current)
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
  end
end
