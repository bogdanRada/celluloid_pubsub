module CelluloidPubsub
  class Redis
    class << self
      include Celluloid
      include Celluloid::Logger

      @connected ||= false
      attr_accessor :connected, :connection

      alias_method :connected?, :connected

      def connect(options = {})
        options.stringify_keys! if options.present?
        if options['use_redis'].to_s.downcase == 'true'
          @connected = true
          require 'eventmachine'
          require 'em-hiredis'
          require 'redis'
          EM.run do
            @connection = EM::Hiredis.connect
            yield @connection if block_given?
          end
          EM.error_handler do |error|
            debug error
          end
        else
          @connection = nil
          @connected = false
        end
      end

    end
  end
end
