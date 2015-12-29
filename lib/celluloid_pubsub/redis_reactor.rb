require_relative './reactor'
module CelluloidPubsub
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

    def shutdown
      super
      async.redis_action('unsubscribe')
    end

    def unsubscribe_all
      CelluloidPubsub::Registry.channels.map do |channel|
        async.redis_action('unsubscribe', channel)
      end
      info 'clearing connections'
      shutdown
    end

    private

    def redis_action(action, channel = nil, message = {})
      CelluloidPubsub::Redis.connect do |connection|
        pubsub = connection.pubsub
        pubsub.on(:unsubscribe) { |channel, remaining_subscriptions|
          debug [:unsubscribe_happened, channel, remaining_subscriptions].inspect
        }

        if action == 'subscribe' && channel.present?
          subscription = pubsub.subscribe(channel) {|subscribed_message|
              @websocket << subscribed_message
          }
          subscription.callback { |reply|
            @websocket << message.merge('client_action' => 'successful_subscription', 'channel' => channel, 'subscriptions' => reply).to_json
          }
          subscription.errback {|reply| debug "subscription error #{reply.inspect}" }
        else
          if channel.present?
            unsubscription = pubsub.unsubscribe(channel)
            unsubscription.callback {|reply| debug "unsubscription success #{reply.inspect}" }
            unsubscription.errback {|reply| debug "unsubscription error #{reply.inspect}" }
          else
            connection.unsubscribe
          end

        end


      end
    end

  end
end
