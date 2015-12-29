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

    def fetch_pubsub
      CelluloidPubsub::Redis.connect do |connection|
        yield connection.pubsub
      end
    end

    def redis_action(action, channel = nil, message = {})
      fetch_pubsub do |pubsub|
        log_unsubscriptions(pubsub)
        callback = fetch_callback_action(action)
        sucess_message =  action == 'subscribe' ? message.merge('client_action' => 'successful_subscription', 'channel' => channel) : nil
        subscription = pubsub.send(action, channel, callback)
        handle_redis_action(subscription, action, sucess_message)
      end
    end

    def fetch_callback_action(action)
      proc do |subscribed_message|
        action == 'subscribe' ? (@websocket << subscribed_message) : log_debug(message)
      end
    end

    def log_unsubscriptions(pubsub)
      pubsub.on(:unsubscribe) do |subscribed_channel, remaining_subscriptions|
        log_debug [:unsubscribe_happened, subscribed_channel, remaining_subscriptions].inspect
      end
    end

    def handle_redis_action(subscription, action, sucess_message = nil)
      register_redis_callback(subscription, sucess_message)
      register_redis_error_callback(subscription, action)
    end

    def register_redis_callback(subscription, sucess_message = nil)
      subscription.callback do |subscriptions_ids|
        if sucess_message.present?
          @websocket << sucess_message.merge('subscriptions' => subscriptions_ids).to_json
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
