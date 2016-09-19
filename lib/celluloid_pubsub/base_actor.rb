# encoding: utf-8
# frozen_string_literal: true
require_relative './helper'
module CelluloidPubsub
  # base actor used for compatibility between celluloid versions
  module BaseActor
    class << self
      include Helper

      attr_reader :config

      def included(base)
        [
          Celluloid,
          Celluloid::IO,
          CelluloidPubsub::Helper,
          config['logger_class']
        ].each do |module_name|
          base.send(:include, module_name)
        end
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
        verify_gem_version(celluloid_version, '0.17', operator: '<')
      end

      def setup_actor_supervision(class_name, options)
        actor_name, args = options.slice(:actor_name, :args).values
        if version_less_than_seventeen?
          class_name.supervise_as(actor_name, args)
        else
          class_name.supervise(as: actor_name, args: [args].compact)
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
