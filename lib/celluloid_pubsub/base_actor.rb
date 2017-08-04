# encoding: utf-8
# frozen_string_literal: true
require_relative './helper'
module CelluloidPubsub
  # base actor used for compatibility between celluloid versions
  # @!attribute [r] config
  #   @return [Hash] The configuration classes and their aliases
  module BaseActor
    class << self
      include Helper

      # includes all the required modules in the class that includes this module
      # @param [Class] base the class that will be used to include the required modules into it
      # @return [void]
      #
      # @api public
      def included(base)
        [
          Celluloid,
          Celluloid::IO,
          Celluloid::Notifications,
          CelluloidPubsub::Helper,
          config['logger_class']
        ].each do |module_name|
          base.send(:include, module_name)
        end
      end

      # returns the configuration classes and their aliases for celluloid
      # @return [Hash] returns the configuration classes and their aliases for celluloid
      #
      # @api public
      def config
        {
          'logger_class' => celluloid_logger_class
        }
      end

      # returns the logger class from celluloid depending on version
      # @return [Class] returns the logger class from celluloid depending on version
      #
      # @api public
      def celluloid_logger_class
        if version_less_than_seventeen?
          Celluloid::Logger
        else
          Celluloid::Internals::Logger
        end
      end

      # returns the celluloid version loaded
      # @return [String] returns the celluloid version loaded
      #
      # @api public
      def celluloid_version
        find_loaded_gem_property('celluloid', 'version')
      end

      # returns true if celluloid version less than 0.17, otherwise false
      # @return [Boolean] returns true if celluloid version less than 0.17, otherwise false
      #
      # @api public
      def version_less_than_seventeen?
        verify_gem_version(celluloid_version, '0.17', operator: '<')
      end

      def setup_actor_supervision_details(class_name, options)
        arguments = (options[:args].is_a?(Array) ? options[:args] : [options[:args]]).compact
        if version_less_than_seventeen?
          options[:type].present? ? [options[:actor_name], options[:type], *arguments] : [options[:actor_name], *arguments]
        else
          #supervises_opts = options[:supervises].present? ? { supervises: options[:supervises] } : {}
          { as: options[:actor_name], type: options[:type], args: arguments, size: options.fetch(:size, nil) }.delete_if{ |key, value| value.blank? }
        end
      end

      def setup_actor_supervision(class_name, options)
        if version_less_than_seventeen?
          class_name.supervise_as(*setup_actor_supervision_details(class_name, options))
        else
          class_name.supervise setup_actor_supervision_details(class_name, options)
        end
      end

      def setup_supervision_group
        if version_less_than_seventeen?
          Celluloid::SupervisionGroup.run!
        else
          Celluloid::Supervision::Container.run!
        end
      end

      def setup_pool_of_actor(class_name, options)
        if version_less_than_seventeen?
          class_name.pool(options[:type], as: options[:actor_name], size:  options.fetch(:size, 10))
        else
          # config = Celluloid::Supervision::Configuration.new
          # config.define setup_actor_supervision_details(class_name, options)
          options = setup_actor_supervision_details(class_name, options)
          class_name.pool *[options[:type], options.except(:type)]
        end
      end
    end
  end
end


if CelluloidPubsub::BaseActor.version_less_than_seventeen?
  require 'celluloid'
  require 'celluloid/autostart'
else
  require 'celluloid/current'
  celluloid_running = Celluloid.running? rescue false
  Celluloid.boot unless celluloid_running
  require 'celluloid'
end
