module CelluloidPubsub
  class Redis
    class << self

      @connected ||= false
      attr_accessor :connected, :connection

      alias_method :connected?, :connected

      def connect(options = {})
        require 'eventmachine'
        require 'em-hiredis'
        require 'redis'
        EM.run do
          @connection = EM::Hiredis.connect
          @connected = true
          yield @connection if block_given?
        end
        EM.error_handler do |error|
          puts error
        end
      end

    end
  end
end
