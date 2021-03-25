# encoding: utf-8
# frozen_string_literal: true

module CelluloidPubsub
  # class used to register new channels and save them in memory
  # @attr  channels
  #   @return [Array] array of channels to which actors have subscribed to
  class Registry
    class << self
      # The channels that the server can handle
      # @return [Array] array of channels to which actors have subscribed to
      attr_writer :channels

      # Messages that are published before any clients being subscribed to those channels
      # will be kept here until a client subscribes to that channel
      # @return [Hash] key-value pairs containing the channel and the messages that were published
      attr_writer :messages

      # holds a list of all messages sent by clients that were not published
      # to a channel because there were no subscribers at that time
      #
      # The keys are the channel names and the values are arrays of messages
      #
      # @return [Hash<String, Array<Hash>>]
      #
      # @api private
      def messages
        @messages ||= {}
      end

      #  holds a list of all known channels
      #
      # @return [Array<String>]
      #
      # @api private
      def channels
        @channels ||= []
      end
    end
  end
end
