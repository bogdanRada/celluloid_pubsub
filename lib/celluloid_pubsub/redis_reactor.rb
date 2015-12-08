require_relative './reactor'
module CelluloidPubsub
  class RedisReactor < CelluloidPubsub::Reactor


    def unsubscribe(channel)
      CelluloidPubsub::Redis.connection.unsubscribe(channel)
      super
    end


    def add_subscriber_to_channel(channel, message)
      super
      CelluloidPubsub::Redis.connect if @server.redis_enabled? && !CelluloidPubsub::Redis.connected?
      CelluloidPubsub::Redis.connection.subscribe(channel) do |on|
        on.subscribe do |subscribed_channel, subscriptions|
          @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => subscribed_channel, "subscriptions" =>subscriptions ).to_json
        end

        on.unsubscribe do |subscribed_channel, subscriptions|
          debug "Unsubscribed from ##{subscribed_channel} (#{subscriptions} subscriptions)" if @server.debug_enabled?
          unsubscribe_from_channel(channel)
          terminate
        end

        on.message do |subscribed_channel, subscribed_message|
          shutdown if message == "exit"

          @websocket << event.to_json
        end
      end
    rescue Reel::SocketError
      info "Client disconnected"
      terminate
    end

    def unsubscribe_from_channel(channel)
      CelluloidPubsub::Redis.connection.unsubscribe(channel)
      super
    end


    def shutdown
      CelluloidPubsub::Redis.connection.unsubscribe
      super
    end


    def unsubscribe_all
      CelluloidPubsub::Registry.channels.map do |channel|
        CelluloidPubsub::Redis.connection.unsubscribe(channel)
      end

      info "clearing connections"
      shutdown
    end

  end
end
