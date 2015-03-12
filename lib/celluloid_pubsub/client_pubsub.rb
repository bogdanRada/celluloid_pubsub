module CelluloidPubsub
  class Client
    class PubSubWorker
      include Celluloid
      include Celluloid::Logger
      attr_accessor :actor, :connect_blk, :cllient

      def initialize(options, &connect_blk)
        options = options.stringify_keys!
        @actor = options['actor'].present? ? options['actor'] : nil
        raise "#{self}: Please provide an actor in the options list!!!" if @actor.blank?
        @connect_blk = connect_blk
        @client = Celluloid::WebSocket::Client.new("ws://#{CelluloidPubsub::WebServer::HOST}:#{CelluloidPubsub::WebServer::PORT}#{CelluloidPubsub::WebServer::PATH}", Actor.current)
      end

      def debug_enabled?
        CelluloidPubsub::WebServer.debug_enabled?
      end

      def subscribe(channel)
        subscription_data = { 'client_action' => 'subscribe', 'channel' => channel }
        debug("#{self.class} tries to subscribe  #{subscription_data}") if debug_enabled?
        async.chat(subscription_data)
      end

      def publish(channel, data)
        publishing_data = { 'client_action' => 'publish', 'channel' => channel, 'data' => data }
        debug(" #{self.class}  publishl to #{channel} message:  #{publishing_data}") if debug_enabled?
        async.chat(publishing_data)
      end

      def on_open
        debug("#{self.class} websocket connection opened") if debug_enabled?
        @connect_blk.call Actor.current
      end

      def on_message(data)
        debug("#{self.class} received  plain #{data}") if debug_enabled?
        message = JSON.parse(data)
        debug("#{self.class} received JSON  #{message}") if debug_enabled?
        @actor.async.on_message(message)
      end

      def on_close(code, reason)
        @client.terminate
        terminate
        debug("#{self.class} dispatching on close  #{code} #{reason}") if debug_enabled?
        @actor.async.on_close(code, reason)
      end

    private

      def chat(message)
        final_message = nil
        if message.is_a?(Hash)
          debug("#{self.class} sends #{message.to_json}") if debug_enabled?
          final_message = message.to_json
        else
          text_messsage = JSON.dump(action: 'message', message: message)
          debug("#{self.class} sends JSON  #{text_messsage}") if debug_enabled?
          final_message = text_messsage
        end
        @client.text final_message
      end
    end

    def self.connect(options = {}, &connect_blk)
      CelluloidPubsub::Client::PubSubWorker.new(options, &connect_blk)
    end
  end
end
