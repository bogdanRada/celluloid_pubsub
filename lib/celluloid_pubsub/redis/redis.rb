require_relative '../helper'
module CelluloidPubsub
  # class that handles redis connection
  class Redis
    class << self
      include Celluloid::Logger
      include CelluloidPubsub::Helper

      @connected ||= false
      attr_accessor :connected, :connection

      alias_method :connected?, :connected

      def connect(&block)
        require 'eventmachine'
        require 'em-hiredis'
        run_the_eventmachine(&block)
        setup_em_exception_handler
      end

    private

      def run_the_eventmachine(&block)
        EM.run do
          @connection = EM::Hiredis.connect
          @connected = true
          block.call @connection
        end
      end

      def setup_em_exception_handler
        EM.error_handler do |error|
          debug error unless filtered_error?(error)
        end
      end
    end
  end
end
