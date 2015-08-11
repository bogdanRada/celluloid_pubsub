module CelluloidPubsub 
  class Config
    
    class << self
    
      def config
        @@config||={}
      end

      def config=(value)
        @@config = value
      end
    
      def backward_compatible
        celluloid_version =  Celluloid::VERSION.to_s.split('.')
        if celluloid_version[0].to_i == 0 && celluloid_version[1].to_i <= 16
          require 'celluloid'
          self.config   = {
            'logger_class'  =>  Celluloid::Logger
          }
        else
          require 'celluloid/current' 
          self.config  = {
            'logger_class'  =>  Celluloid::Internals::Logger
          }
        end 
      end
    
    end
  end
end
