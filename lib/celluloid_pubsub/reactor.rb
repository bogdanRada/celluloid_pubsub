require_relative './registry'
module CelluloidPubsub
  class Reactor
    include Celluloid
    include Celluloid::IO
    include Celluloid::Logger

    attr_accessor :websocket, :server, :mutex

    def work(websocket, server)
      @server = server
      @mutex = Mutex.new
      @websocket = websocket
      info "Streaming changes for #{websocket.url}" if @server.debug_enabled?
      async.run
    end

    def run
      while message = @websocket.read
        handle_websocket_message(message)
      end
    end

    def parse_json_data(message)
      debug "Reactor read message  #{message}" if @server.debug_enabled?
      json_data = nil
      begin
        json_data = JSON.parse(message)
      rescue => e
        debug "Reactor could not parse #{message} because of #{e.inspect}" if @server.debug_enabled?
        # do nothing
      end
      json_data = message if json_data.nil?
      json_data
    end

    def handle_websocket_message(message)
      json_data = parse_json_data(message)
      handle_parsed_websocket_message(json_data)
    end

    def handle_parsed_websocket_message(json_data)
      if json_data.is_a?(Hash)
        json_data = json_data.stringify_keys
        debug "Reactor finds actions for  #{json_data}" if @server.debug_enabled?
        delegate_action(json_data) if json_data['client_action'].present?
      else
        handle_unknown_action(json_data)
      end
    end

    def delegate_action(json_data)
      case json_data['client_action']
        when 'unsubscribe_all'
          unsubscribe_all
        when 'unsubscribe'
          async.unsubscribe_client(json_data['channel'])
        when 'subscribe'
          async.start_subscriber(json_data['channel'], json_data)
        when 'publish'
          @server.publish_event(json_data['channel'], json_data['data'].to_json)
        else
          handle_unknown_action(json_data)
      end
    end

    def handle_unknown_action(json_data)
      debug "Trying to dispatch   to server  #{json_data}" if @server.debug_enabled?
      @server.async.handle_dispatched_message(Actor.current, json_data)
    end

    def unsubscribe_client(channel)
      return unless channel.present?
      @websocket.close
      @server.unsubscribe_client(Actor.current, channel)
    end

    def shutdown
      terminate
    end

    def start_subscriber(channel, message)
      return unless channel.present?
      @mutex.lock
      begin
        add_subscriber_to_channel(channel, message)
        debug "Subscribed to #{channel} with #{message}" if @server.debug_enabled?
        @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel).to_json
      rescue => e
        raise [e, e.respond_to?(:backtrace) ? e.backtrace : '', channel, message].inspect
      ensure
        @mutex.unlock
      end
    end

    def add_subscriber_to_channel(channel, message)
      CelluloidPubsub::Registry.channels << channel unless CelluloidPubsub::Registry.channels.include?(channel)
      @server.subscribers[channel] ||= []
      @server.subscribers[channel] << { reactor: Actor.current, message: message }
    end

    def unsubscribe_all
      CelluloidPubsub::Registry.channels.map do |channel|
        @subscribers[channel].each do |hash|
          hash[:reactor].websocket.close
        end
        @server.subscribers[channel] = []
      end

      info 'clearing connections' if @server.debug_enabled?
      shutdown
    end
  end
end
