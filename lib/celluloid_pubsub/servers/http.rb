# encoding: utf-8
# frozen_string_literal: true
require_relative '../server_actor'
module CelluloidPubsub
  class Server
    # webserver to which socket connects should connect to .
    # the server will dispatch each request into a new Reactor
    # which will handle the action based on the message
    # @attr  server_options
    #   @return [Hash] options used to configure the webserver
    #   @option server_options [String]:hostname The hostname on which the webserver runs on
    #   @option server_options [Integer] :port The port on which the webserver runs on
    #   @option server_options [String] :path The request path that the webserver accepts
    #   @option server_options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
    #
    # @attr  subscribers
    #   @return [Hash] The hostname on which the webserver runs on
    # @attr  mutex
    #   @return [Mutex] The mutex that will synchronize actions on subscribers
    class HTTP < Reel::Server::HTTP
      include CelluloidPubsub::ServerActor

      #  receives a list of options that are used to configure the webserver
      #
      # @param  [Hash]  options the options that can be used to connect to webser and send additional data
      # @option options [String]:hostname The hostname on which the webserver runs on
      # @option options [Integer] :port The port on which the webserver runs on
      # @option options [String] :path The request path that the webserver accepts
      # @option options [Boolean] :spy Enable this only if you want to enable debugging for the webserver
      #
      # @return [void]
      #
      # @api public
      #
      # :nocov:
      def initialize(app, options = {})
        CelluloidPubsub.config.secure = false
        initialize_server(app, options) do
          options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
          super(hostname, port, { spy: spy, backlog: backlog }.merge(options), &method(:on_connection))
        end
      end

    end
  end
end
