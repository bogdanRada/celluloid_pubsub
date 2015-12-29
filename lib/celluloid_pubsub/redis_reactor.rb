require_relative './reactor'
module CelluloidPubsub
  class RedisReactor < CelluloidPubsub::Reactor
    include Celluloid
    include Celluloid::IO
    include Celluloid::Logger

    def unsubscribe(channel)
      async.redis_unsubscribe_channel(channel)
      super
    end

    def add_subscriber_to_channel(channel, message)
      super
      async.redis_subscribe(channel, message)
    end

    def unsubscribe_from_channel(channel)
      async.redis_unsubscribe_channel(channel)
      super
    end

    def shutdown
      check_redis_connection do |connection|
        connection.unsubscribe
      end
      super
    end

    def unsubscribe_all
      CelluloidPubsub::Registry.channels.map do |channel|
        async.redis_unsubscribe_channel(channel)
      end
      info 'clearing connections'
      shutdown
    end

    private

    def redis_unsubscribe_channel(channel)
      CelluloidPubsub::Redis.connect do |connection|
        pubsub = connection.pubsub
        pubsub.unsubscribe(channel)
      end
    end

    def redis_subscribe(channel, message)
      CelluloidPubsub::Redis.connect do |connection|
        pubsub = connection.pubsub

        subscription = pubsub.subscribe(channel) {|subscribed_message|
          @websocket << subscribed_message
        }
        subscription.callback { |reply|
          @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel, 'subscriptions' => reply).to_json
        }
        pubsub.on(:unsubscribe) { |channel, remaining_subscriptions|
          debug "Unsubscribed from ##{subscribed_channel} (#{subscriptions} subscriptions)" if @server.debug_enabled?
          unsubscribe_from_channel(channel)
          terminate
        }
      end
    end

  end
end
