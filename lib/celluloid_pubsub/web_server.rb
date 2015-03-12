require_relative './reactor'
module CelluloidPubsub
  class WebServer < Reel::Server::HTTP
    include Celluloid::Logger

    HOST = '0.0.0.0'
    PORT = 1234
    PATH = '/ws'

    attr_accessor :options, :subscribers, :backlog

    def initialize(options = {})
      parse_options(options)
      @subscribers = {}
      info "CelluloidPubsub::WebServer example starting on #{@hostname}:#{@port}" if debug_enabled?
      super(@hostname, @port, { spy: @spy, backlog: @backlog }, &method(:on_connection))
    end

    def parse_options(options)
      raise 'Options is not a hash or is not present ' unless options.is_a?(Hash)
      @options = options.stringify_keys
      @backlog = @options.fetch(:backlog, 1024)
      @hostname = @options.fetch(:hostname, CelluloidPubsub::WebServer::HOST)
      @port = @options.fetch(:port, CelluloidPubsub::WebServer::PORT)
      @path = @options.fetch(:path, CelluloidPubsub::WebServer::PATH)
      @spy = @options.fetch(:spy, false)
    end

    def debug_enabled?
      self.class.debug_enabled?
    end

    def self.debug_enabled?
      ENV['DEBUG_CELLULOID'].present? && (ENV['DEBUG_CELLULOID'] == 'true' || ENV['DEBUG_CELLULOID'] == true)
    end

    def publish_event(current_topic, message)
      return if current_topic.blank? || message.blank?
      @subscribers[current_topic].each do |hash|
        hash[:reactor].websocket << message
      end
    end

    def on_connection(connection)
      while request = connection.request
        if request.websocket?
          info 'Received a WebSocket connection' if debug_enabled?

          # We're going to hand off this connection to another actor (Writer/Reader)
          # However, initially Reel::Connections are "attached" to the
          # Reel::Server::HTTP actor, meaning that the server manages the connection
          # lifecycle (e.g. error handling) for us.
          #
          # If we want to hand this connection off to another actor, we first
          # need to detach it from the Reel::Server (in this case, Reel::Server::HTTP)
          connection.detach
          route_websocket(request.websocket)
          return
        else
          route_request connection, request
        end
      end
    end

    def route_request(connection, request)
      info "404 Not Found: #{request.path}" if debug_enabled?
      connection.respond :not_found, 'Not found'
    end

    def route_websocket(socket)
      if socket.url == @path
        info 'Reactor handles new socket connection' if debug_enabled?
        reactor = CelluloidPubsub::Reactor.new
        Actor.current.link reactor
        reactor.async.work(socket, Actor.current)
      else
        info "Received invalid WebSocket request for: #{socket.url}" if debug_enabled?
        socket.close
      end
    end

    def handle_dispatched_message(reactor, data)
      debug "Webserver trying to dispatch message  #{data.inspect}" if debug_enabled?
      message = reactor.parse_json_data(data)
      if message.present? && message.is_a?(Hash)
        reactor.websocket << message.to_json
      else
        reactor.websocket << data.to_json
      end
    end
  end
end
