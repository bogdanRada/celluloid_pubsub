# encoding: utf-8
# frozen_string_literal: true
module CelluloidPubsub
  # class used to register new channels and save them in memory
  class Registry
    class << self
      # @!attribute channels
      #   @return [Array] array of channels to which actors have subscribed to
      attr_accessor :channels
    end
    @channels = []
  end
end
