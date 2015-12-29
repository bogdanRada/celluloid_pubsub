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
      options = options.is_a?(Hash) ? options : {}
      options.stringify_keys
    end

    def log_debug(message)
      debug message if debug_enabled?
    end
  end
end
