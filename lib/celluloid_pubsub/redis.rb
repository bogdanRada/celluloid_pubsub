module CelluloidPubsub
  class Redis
    class << self
      @connected ||= false
      attr_accessor :connected, :connection

      alias_method :connected?, :connected

      def connect(_options = {})
        require 'eventmachine'
        require 'em-hiredis'
        EM.run do
          @connection = EM::Hiredis.connect
          @connected = true
          yield @connection if block_given?
        end
        EM.error_handler do |error|
          unless error.is_a?(Interrupt)
            puts error.inspect
          end
        end
      end
    end
  end
end
