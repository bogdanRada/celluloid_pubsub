require_relative './helper'
module CelluloidPubsub
  # class used to store the config with backward compatible classes
  class BackwardCompatible
    extend Helper

    class << self
      attr_accessor :config

      def config
        {
          'logger_class' => celluloid_logger_class
        }
      end

      def celluloid_logger_class
        if version_less_than_sixten?
          Celluloid::Logger
        else
          Celluloid::Internals::Logger
        end
      end

      def version_less_than_sixten?
        verify_celluloid_version("0.16", '<=', :optional_fields => [:tiny])
      end

    end
  end
end

if CelluloidPubsub::BackwardCompatible.version_less_than_sixten?
  require 'celluloid'
else
  require 'celluloid/current'
end
