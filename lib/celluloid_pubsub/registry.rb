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
      attr_accessor :channels
    end
    @channels = []
  end
end
