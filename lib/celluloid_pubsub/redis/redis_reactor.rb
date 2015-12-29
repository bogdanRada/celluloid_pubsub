require_relative '../reactor'
module CelluloidPubsub
  # reactor used for redis pubsub
  class RedisReactor < CelluloidPubsub::Reactor
    include Celluloid
    include Celluloid::IO
    include Celluloid::Logger

    def unsubscribe(channel)
      super
      async.redis_action('unsubscribe', channel)
    end

    def add_subscriber_to_channel(channel, message)
      super
      async.redis_action('subscribe', channel, message)
    end

    def unsubscribe_from_channel(channel)
      super
      async.redis_action('unsubscribe', channel)
    end

    def unsubscribe_all
      CelluloidPubsub::Registry.channels.map do |channel|
        async.redis_action('unsubscribe', channel)
      end
      info 'clearing connections'
      shutdown
    end

    def shutdown
      @channels.each do |channel|
        redis_action('unsubscribe', channel)
      end if @channels.present?
      super
    end

    private

    def redis_action(action, channel = nil, message = {})
      CelluloidPubsub::Redis.connect do |connection|
        pubsub = connection.pubsub
        handle_on_subsubscribe_log(pubsub)
        handle_redis_action(pubsub, action, channel, message)
      end
    end

    def handle_on_subsubscribe_log(pubsub)
      pubsub.on(:unsubscribe) do |subscribed_channel, remaining_subscriptions|
        debug [:unsubscribe_happened, subscribed_channel, remaining_subscriptions].inspect if debug_enabled?
      end
    end

    def handle_redis_action(pubsub, action, channel, message)
      callback = proc{ |subscribed_message|
        action == 'subscribe' ? (@websocket << subscribed_message) : log_debug(message)
      }
      subscription = pubsub.send(action, channel, callback)
      register_redis_callback(subscription,action,channel, message)
      register_redis_error_callback(subscription, action)
    end

    def register_redis_callback(subscription, action, channel, message)
      subscription.callback do |subscriptions_ids|
        if action == 'subscribe'
          @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel, 'subscriptions' => subscriptions_ids).to_json
        else
          log_debug "#{action} success #{success_response.inspect}"
        end
      end
    end

    def register_redis_error_callback(subscription, action)
      subscription.errback { |reply| log_debug "#{action} error #{reply.inspect}" }
    end

  end
end
