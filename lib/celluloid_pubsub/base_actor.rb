require_relative './helper'
module CelluloidPubsub
  # base actor used for compatibility between celluloid versions
  module BaseActor
    extend Helper

    class << self
      attr_reader :config

      def included(base)
        base.include Celluloid
        base.include Celluloid::IO
        base.include CelluloidPubsub::Helper
        base.include config['logger_class']
      end

      def config
        {
          'logger_class' => celluloid_logger_class
        }
      end

      def celluloid_logger_class
        if version_less_than_seventeen?
          Celluloid::Logger
        else
          Celluloid::Internals::Logger
        end
      end

      def celluloid_version
        find_loaded_gem_property('celluloid', 'version')
      end

      def version_less_than_seventeen?
        verify_gem_version('celluloid', '0.17', operator: '<')
      end

      def setup_actor_supervision(class_name, options)
        if version_less_than_seventeen?
          class_name.supervise_as(options[:actor_name], options[:args])
        else
          class_name.supervise(as: options[:actor_name], args: [options[:args]])
        end
      end

    end
  end
end

if CelluloidPubsub::BaseActor.version_less_than_seventeen?
  require 'celluloid/autostart'
else
  require 'celluloid/current'
end
