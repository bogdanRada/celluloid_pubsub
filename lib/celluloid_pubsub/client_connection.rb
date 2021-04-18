require 'celluloid/websocket/client/connection'
require 'websocket/driver'
require_relative './helper'
module CelluloidPubsub
  class ClientConnection < ::Celluloid::WebSocket::Client::Connection
    include CelluloidPubsub::Helper

    finalizer :shutdown
    trap_exit :actor_died

    def initialize(url, handler)
      @shutting_down = false
      super(url, handler)
    end

    def run
      super
    rescue EOFError, Errno::ECONNRESET, StandardError
      @client.emit(:close, ::WebSocket::Driver::CloseEvent.new(1001, 'server closed connection'))
    end

    # the method will return true if the actor is shutting down
    #
    #
    # @return [Boolean] returns true if the actor is shutting down
    #
    # @api public
    def shutting_down?
      @shutting_down == true
    end

    # the method will terminate the current actor
    #
    #
    # @return [void]
    #
    # @api public
    def shutdown
      @shutting_down = true
      log_debug "#{self.class} tries to 'shutdown'"
      terminate
    end

    # method called when the actor is exiting
    #
    # @param [actor] actor - the current actor
    # @param [Hash] reason - the reason it crashed
    #
    # @return [void]
    #
    # @api public
    def actor_died(actor, reason)
      @shutting_down = true
      log_debug "Oh no! #{actor.inspect} has died because of a #{reason.class}"
    end
  end
end