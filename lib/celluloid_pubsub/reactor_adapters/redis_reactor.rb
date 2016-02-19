gem 'em-hiredis', '~> 0.3'
require 'em-hiredis'

require_relative './reactor'
require_relative '../helpers/application_helper'
module CelluloidPubsub
  # reactor used for redis pubsub
  # @!attribute connected
  #   @return [Boolean] returns true if already connected to redis
  # @!attribute connection
  #   @return [EM::Hiredis] The connection used for redis
  class RedisReactor < CelluloidPubsub::Reactor
    include Celluloid
    include Celluloid::IO
    include Celluloid::Logger
    include CelluloidPubsub::ApplicationHelper

    attr_accessor :connected, :connection

    alias_method :connected?, :connected

    # returns true if already connected to redis otherwise false
    #
    # @return [Boolean] returns true if already connected to redis otherwise false
    #
    # @api public
    def connected
      @connected ||= false
    end

    # method used to unsubscribe from a channel
    # @see #redis_action
    #
    # @return [void]
    #
    # @api public
    def unsubscribe(channel)
      super
      async.redis_action('unsubscribe', channel)
    end

    # method used to subscribe to a channel
    # @see #redis_action
    #
    # @return [void]
    #
    # @api public
    def add_subscriber_to_channel(channel, message)
      super
      async.redis_action('subscribe', channel, message)
    end

    # method used to unsubscribe from a channel
    # @see #redis_action
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_from_channel(channel)
      super
      async.redis_action('unsubscribe', channel)
    end

    # method used to unsubscribe  from all channels
    # @see #redis_action
    #
    # @return [void]
    #
    # @api public
    def unsubscribe_all
      info 'clearing connections'
      shutdown
    end

    # method used to shutdown the reactor and unsubscribe from all channels
    # @see #redis_action
    #
    # @return [void]
    #
    # @api public
    def shutdown
      @channels.dup.each do |channel|
        redis_action('unsubscribe', channel)
      end if @channels.present?
      super
    end

    # method used to publish event using redis
    #
    # @return [void]
    #
    # @api public
    def publish_event(topic, data)
      return if topic.blank? || data.blank?
      connect_to_redis do |connection|
        connection.publish(topic, data)
      end
    rescue => exception
      log_debug("could not publish message #{message} into topic #{current_topic} because of #{exception.inspect}")
    end

  private

    # method used to run the enventmachine and setup the exception handler
    # @see #run_the_eventmachine
    # @see #setup_em_exception_handler
    #
    # @param [Proc] block the block that will use the connection
    #
    # @return [void]
    #
    # @api private
    def connect_to_redis(&block)
      require 'eventmachine'
      require 'em-hiredis'
      run_the_eventmachine(&block)
      setup_em_exception_handler
    end

    # method used to connect to redis and yield the connection
    #
    # @param [Proc] block the block that will use the connection
    #
    # @return [void]
    #
    # @api private
    def run_the_eventmachine(&block)
      EM.run do
        @connection ||= EM::Hiredis.connect
        @connected = true
        block.call @connection
      end
    end

    # method used to setup the eventmachine exception handler
    #
    # @return [void]
    #
    # @api private
    def setup_em_exception_handler
      EM.error_handler do |error|
        debug error unless filtered_error?(error)
      end
    end

    # method used to fetch the pubsub client from the connection and yield it
    #
    # @return [void]
    #
    # @api private
    def fetch_pubsub
      connect_to_redis do |connection|
        @pubsub ||= connection.pubsub
        yield @pubsub if block_given?
      end
    end

    # method used to fetch the pubsub client from the connection and yield it
    # @see #action_subscribe
    #
    # @param [string] action The action that will be checked
    # @param [string] channel The channel that reactor has subscribed to
    # @param [string] message The initial message used to subscribe
    #
    # @return [void]
    #
    # @api private
    def action_success(action, channel, message)
      action_subscribe?(action) ? message.merge('client_action' => 'successful_subscription', 'channel' => channel) : nil
    end

    # method used execute an action (subscribe or unsubscribe ) to redis
    # @see #prepare_redis_action
    # @see #action_success
    # @see #register_subscription_callbacks
    #
    # @param [string] action The action that will be checked
    # @param [string] channel The channel that reactor has subscribed to
    # @param [string] message The initial message used to subscribe
    #
    # @return [void]
    #
    # @api private
    def redis_action(action, channel = nil, message = {})
      fetch_pubsub do |pubsub|
        callback = prepare_redis_action(pubsub, action)
        success_message = action_success(action, channel, message)
        args = action_subscribe?(action) ? [channel, callback] : [channel]
        subscription = pubsub.send(action, *args)
        register_subscription_callbacks(subscription, action, success_message)
      end
    end

    # method used check if the action is subscribe and write the incoming message to be websocket or log the message otherwise
    # @see #log_unsubscriptions
    # @see #action_subscribe
    #
    # @param [String] action The action that will be checked if it is subscribed
    #
    # @return [void]
    #
    # @api private
    def prepare_redis_action(pubsub, action)
      log_unsubscriptions(pubsub)
      proc do |subscribed_message|
        action_subscribe?(action) ? (@websocket << subscribed_message) : log_debug(message)
      end
    end

    # method used to listen to unsubscriptions and log them to log file
    # @see #register_redis_callback
    # @see #register_redis_error_callback
    #
    # @param [EM::Hiredis::PubsubClient] pubsub The pubsub client that will be used to listen to unsubscriptions
    #
    # @return [void]
    #
    # @api private
    def log_unsubscriptions(pubsub)
      pubsub.on(:unsubscribe) do |subscribed_channel, remaining_subscriptions|
        log_debug [:unsubscribe_happened, subscribed_channel, remaining_subscriptions].inspect
      end
    end

    # method used registers the sucess and error callabacks
    # @see #register_redis_callback
    # @see #register_redis_error_callback
    #
    # @param [EM::DefaultDeferrable] subscription The subscription object
    # @param [string] action The action that will be checked
    # @param [string] sucess_message The initial message used to subscribe
    #
    # @return [void]
    #
    # @api private
    def register_subscription_callbacks(subscription, action, sucess_message = nil)
      register_redis_callback(subscription, action, sucess_message)
      register_redis_error_callback(subscription, action)
    end

    # the method will return true if debug is enabled
    #
    #
    # @return [Boolean] returns true if debug is enabled otherwise false
    #
    # @api public
    def debug_enabled?
      @server.debug_enabled?
    end

    # method used to register a success callback  and if action is subscribe will write
    # back to the websocket a message that will say it is a successful_subscription
    # If action is something else, will log the incoming message
    # @see #log_debug
    #
    # @param [EM::DefaultDeferrable] subscription The subscription object
    # @param [string] sucess_message The initial message used to subscribe
    #
    # @return [void]
    #
    # @api private
    def register_redis_callback(subscription, action, sucess_message = nil)
      subscription.callback do |subscriptions_ids|
        if sucess_message.present?
          @websocket << sucess_message.merge('subscriptions' => subscriptions_ids).to_json
        else
          log_debug "#{action} success #{sucess_message.inspect}"
        end
      end
    end

    # Register an error callback on the deferrable object and logs to file the incoming message
    # @see #log_debug
    #
    # @param [EM::DefaultDeferrable] subscription The subscription object
    # @param [string] action The action that will be checked
    #
    # @return [void]
    #
    # @api private
    def register_redis_error_callback(subscription, action)
      subscription.errback { |reply| log_debug "#{action} error #{reply.inspect}" }
    end
  end
end
