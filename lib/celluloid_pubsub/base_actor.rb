require_relative './helper'
module CelluloidPubsub
  # base actor used for compatibility between celluloid versions
  class BaseActor
    extend Helper

    class << self
      attr_reader :config

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

      def celluloid_version
        find_loaded_gem_property('celluloid', 'version')
      end

      def version_less_than_sixten?
        verify_gem_version('celluloid', '0.16', operator: '<=')
      end

      def setup_actor_supervision(class_name, options)
        if version_less_than_sixten?
          class_name.supervise_as(options[:actor_name], options[:args])
        else
          class_name.supervise(as: options[:actor_name], args: [options[:args]])
        end
      end

    end

    include Celluloid
    include Celluloid::IO
    include config['logger_class']
  end
end

if CelluloidPubsub::BaseActor.version_less_than_sixten?
  require 'celluloid'
else
  require 'celluloid/current'
end
