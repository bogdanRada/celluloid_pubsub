# encoding: utf-8
# frozen_string_literal: true

require_relative './gem_version_parser'
module CelluloidPubsub
  # class that holds the options that are configurable for this gem
  module Helper
    # checks if the message has the successfull subscription action
    #
    # @param [string] message The message that will be checked
    #
    # @return [Boolean] return true if message contains key client_action with value 'succesfull_subscription'
    #
    # @api public
    def succesfull_subscription?(message)
      message.is_a?(Hash) && message['client_action'] == 'successful_subscription'
    end

    # the method try to decide if an actor is dead
    # In Celluloid 0.18 there is no `dead?` method anymore
    #  So we are trying to be backward-compatible with older versions
    #
    # @param [Celluloid::Actor] actor
    # @return [Boolean] returns true if the actor is dead, otherwise false
    #
    # @api public
    def actor_dead?(actor)
      raise actor.class.inspect if !actor.respond_to?(:dead?) && !actor.respond_to?(:alive?)
      (actor.respond_to?(:dead?) && actor.dead?) ||
        (actor.respond_to?(:alive?) && !actor.alive?)
    end

    # returns the instance of the class that includes the actor, this is useful in tests
    #
    # @return [Object] returns the object
    #
    # @api public
    def own_self
      self
    end

    # returns the current actor
    #
    # @return [::Celluloid::Actor] returns the current actor
    #
    # @api public
    def cell_actor
      ::Celluloid::Actor.current
    end

    module_function

    # returns the gem's property from its speification or nil
    # @param [String] name the name of the gem
    # @param [String] property name of the property we want
    #
    # @return [String, nil] returns the version of the gem
    #
    # @api public
    def find_loaded_gem(name, property = nil)
      gem_spec = Gem.loaded_specs.values.find { |repo| repo.name == name }
      gem_spec.present? && property.present? ? gem_spec.send(property) : gem_spec
    end

    # returns the gem's property from its speification or nil
    # @param [String] gem_name name of the gem
    # @param [String] property name of the property we want
    #
    # @return [String, nil] returns the version of the gem
    #
    # @api public
    def find_loaded_gem_property(gem_name, property = 'version')
      find_loaded_gem(gem_name, property)
    end

    # returns the parsed version of the gem
    # @param [String] gem_name name of the gem
    #
    # @return [Float, nil] returns the version of the gem
    #
    # @api public
    def fetch_gem_version(gem_name)
      version = find_loaded_gem_property(gem_name)
      version.blank? ? nil : get_parsed_version(version)
    end

    # returns the parsed version as a float or nil
    # @param [String] version the version that needs to be parsed
    #
    # @return [Float, nil] returns the version of the gem
    #
    # @api public
    def get_parsed_version(version)
      version_parser = CelluloidPubsub::GemVersionParser.new(version)
      version_parser.parsed_number
    end

    # returns true if gem_version is less or equal to the specified version, otherwise false
    # @param [String] gem_version the version of the gem
    # @param [String] version the version that will be checked against
    # @param [Hash] options additional options
    #
    # @return [Boolean] returns true if gem_version is less or equal to the specified version, otherwise false
    #
    # @api public
    def verify_gem_version(gem_version, version, options = {})
      options.stringify_keys!
      version = get_parsed_version(version)
      get_parsed_version(gem_version).send(options.fetch('operator', '<='), version)
    end

    # method used to determine if a action is a subsribe action
    # @param [string] action The action that will be checked
    #
    # @return [Boolean] Returns true if the action equals to 'subscribe'
    #
    # @api public
    def action_subscribe?(action)
      action == 'subscribe'
    end

    # sets the celluloid logger and the celluloid exception handler
    #
    # @return [void]
    #
    # @api private
    # :nocov:
    def setup_celluloid_logger
      return if !debug_enabled? || (respond_to?(:log_file_path) && log_file_path.blank?)
      setup_log_file
      Celluloid.logger = ::Logger.new(log_file_path).tap do |logger|
        logger.level = respond_to?(:log_level) ? log_level : ::Logger::Severity::INFO
      end
      setup_celluloid_exception_handler
    end
    # :nocov:

    # sets the celluloid exception handler
    #
    # @return [void]
    #
    # @api private
    # :nocov:
    def setup_celluloid_exception_handler
      Celluloid.task_class = defined?(Celluloid::TaskThread) ? Celluloid::TaskThread : Celluloid::Task::Threaded
      Celluloid.exception_handler do |ex|
        unless filtered_error?(ex)
          puts ex
          puts ex.backtrace
          puts ex.cause
        end
      end
    end
    # :nocov:

    # creates the log file where the debug messages will be printed
    #
    # @return [void]
    #
    # @api private
    # :nocov:
    def setup_log_file
      return if !debug_enabled? || (respond_to?(:log_file_path) && log_file_path.blank?)
      FileUtils.mkdir_p(File.dirname(log_file_path)) unless File.directory?(log_file_path)
      log_file = File.open(log_file_path, 'wb')
      log_file.sync = true
    end
    # :nocov:

    # checks if a given error needs to be filtered
    #
    # @param [Exception::Error] error
    #
    # @return [Boolean] returns true if the error should be filtered otherwise false
    #
    # @api private
    def filtered_error?(error)
      [Interrupt].any? { |class_name| error.is_a?(class_name) }
    end

    #  receives a list of options that need to be parsed
    # if it is an Array will return the first element , otherwise if it is
    # an Hash will return the hash with string keys, otherwise an empty hash
    #
    # @param  [Hash, Array]  options the options that need to be parsed
    #
    # @return [Hash]
    #
    # @api private
    def parse_options(options)
      options = options.is_a?(Array) ? options.last : options
      options.is_a?(Hash) ? options.deep_stringify_keys : {}
    end

    #  receives a message, and logs it to the log file if debug is enabled
    #
    # @param  [Object] message
    #
    # @return [void]
    #
    # @api private
    # :nocov:
    def log_debug(message)
      return unless respond_to?(:debug_enabled?)
      return if Celluloid.logger.blank? || !debug_enabled?
      Celluloid.logger.debug(message)
    end
    # :nocov:
  end
end
