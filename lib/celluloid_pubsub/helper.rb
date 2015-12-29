module CelluloidPubsub
  # class that holds the options that are configurable for this gem
  module Helper
    # checks if the message has the successfull subscription action
    #
    # @param [string] message
    #
    # @return [void]
    #
    # @api public
    def succesfull_subscription?(message)
      message.is_a?(Hash) && message['client_action'] == 'successful_subscription'
    end

  module_function

    def setup_celluloid_logger
      return if !debug_enabled? || (respond_to?(:log_file_path) && log_file_path.blank?)
      setup_log_file
      Celluloid.logger = ::Logger.new(log_file_path.present? ? log_file_path : STDOUT)
      setup_celluloid_exception_handler
    end

    def setup_celluloid_exception_handler
      Celluloid.task_class = Celluloid::TaskThread
      Celluloid.exception_handler do |ex|
        puts ex unless filtered_error?(ex)
      end
    end

    def setup_log_file
      return if !debug_enabled? || (respond_to?(:log_file_path) && log_file_path.blank?)
      FileUtils.mkdir_p(File.dirname(log_file_path)) unless File.directory?(log_file_path)
      log_file = File.open(log_file_path, 'w')
      log_file.sync = true
    end

    def filtered_error?(error)
      [Interrupt].any? { |class_name| error.is_a?(class_name) }
    end

    #  receives a list of options that are used to configure the webserver
    #
    # @param  [Hash]  options the options that can be used to connect to webser and send additional data
    # @option options [String]:hostname The hostname on which the webserver runs on
    # @option options [Integer] :port The port on which the webserver runs on
    # @option options [String] :path The request path that the webserver accepts
    # @option options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
    # @option options [Integer]:backlog How many connections the server accepts
    #
    # @return [void]
    #
    # @api public
    def parse_options(options)
      options = options.is_a?(Array) ? options.first : options
      options = options.is_a?(Hash) ? options.stringify_keys : {}
      options
    end

    def log_debug(message)
      debug message if respond_to?(:debug_enabled?) && debug_enabled?
    end
  end
end
