module CelluloidPubsub
  class Redis
    class << self
      @connected ||= false
      attr_accessor :connected, :connection

      alias_method :connected?, :connected
    end

    def self.connect(options={})
      options.stringify_keys! if options.present?
      if options['use_redis'].to_s.downcase == 'true'
        require 'redis'
        require 'celluloid/redis'
        require 'redis/connection/celluloid'
        @connection = ::Redis.new(:driver => :celluloid)
      else
        @connection = nil
      end
    end
  end
end
