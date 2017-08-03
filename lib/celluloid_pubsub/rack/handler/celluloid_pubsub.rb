module Rack
  module Handler
    class CelluloidPubsub

      def self.run(app, options = {})
        options = ::CelluloidPubsub.config.attributes.merge(options)

        app = Rack::CommonLogger.new(app, STDOUT) unless options[:quiet]
        ENV['RACK_ENV'] = options[:environment].to_s if options[:environment]

        server_class = ::CelluloidPubsub.config.secure.to_s.downcase == 'false' ? ::CelluloidPubsub::Server::HTTP : ::CelluloidPubsub::Server::HTTPS

        options[:port] = options[:Port]
        ::CelluloidPubsub::BaseActor.setup_actor_supervision(server_class, actor_name: :celluloid_pubsub_rack_server, args: [app, options] )

        begin
          sleep
        rescue Interrupt
          Celluloid.logger.info "Interrupt received... shutting down"
          supervisor.terminate
        end
      end
    end

    register :celluloid_pubsub, ::Rack::Handler::CelluloidPubsub
  end
end
