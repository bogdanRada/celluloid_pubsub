module CelluloidPubsub
  # class used to store the config with backward compatible classes
  class BackwardCompatible
    class << self
      attr_accessor :config

      def config
        {
          'logger_class' => celluloid_sixteen_or_less? ? Celluloid::Logger : Celluloid::Internals::Logger
        }
      end

      def celluloid_sixteen_or_less?
        celluloid_version = Celluloid::VERSION.to_s.split('.')
        celluloid_version[0].to_i == 0 && celluloid_version[1].to_i <= 16
      end
    end
  end
end
