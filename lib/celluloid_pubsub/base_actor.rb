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
      # :nocov:
      def celluloid_logger_class
        if version_less_than_seventeen?
          Celluloid::Logger
        else
          Celluloid::Internals::Logger
        end
      end
      # :nocov:

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

      # returns true if celluloid version less than 0.18, otherwise false
      # @return [Boolean] returns true if celluloid version less than 0.17, otherwise false
      #
      # @api public
      def version_less_than_eigthteen?
        verify_gem_version(celluloid_version, '0.18', operator: '<')
      end

      # tries to boot up Celluloid if it is not running
      # @return [Boolean] returns true if Celluloid started false otherwise
      #
      # @api public
      def boot_up
        celluloid_running = begin
          Celluloid.running?
        rescue StandardError
          false
        end
        Celluloid.boot unless celluloid_running
      end

      # sets up the actor supervision based on celluloid version
      # @param [Class] class_name The class that will be used to supervise the actor
      # @param [Hash] options Additional options needed for supervision
      # @return [void]
      #
      # @api public
      # :nocov:
      def setup_actor_supervision(class_name, options)
        actor_name, args = options.slice(:actor_name, :args).values
        if version_less_than_seventeen?
          class_name.supervise_as(actor_name, args)
        else
          class_name.supervise(as: actor_name, args: [args].compact)
        end
      end
      # :nocov:
    end
  end
end

# :nocov:
if CelluloidPubsub::BaseActor.version_less_than_seventeen?
  require 'celluloid'
  require 'celluloid/autostart'
elsif CelluloidPubsub::BaseActor.version_less_than_eigthteen?
  require 'celluloid/current'
  CelluloidPubsub::BaseActor.boot_up
  require 'celluloid'
else
  require 'celluloid'
  require 'celluloid/pool'
  require 'celluloid/fsm'
  require 'celluloid/supervision'
  CelluloidPubsub::BaseActor.boot_up
end
# :nocov:
