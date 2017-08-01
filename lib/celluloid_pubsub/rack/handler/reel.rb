module Rack
  module Handler
    class CelluloidPubsub

      def self.run(app, options = {})
        options = CelluloidPubsub.config.attributes.merge(options)

        app = Rack::CommonLogger.new(app, STDOUT) unless options[:quiet]
        ENV['RACK_ENV'] = options[:environment].to_s if options[:environment]

        server_class = CelluloidPubsub.config.secure.to_s.downcase == 'true' ? CelluloidPubsub::Server::HTTP : CelluloidPubsub::Server::HTTPS

        supervisor = server_class.supervise(as: :reel_rack_server, args: [app, options])

        begin
          sleep
        rescue Interrupt
          Celluloid.logger.info "Interrupt received... shutting down"
          supervisor.terminate
        end
      end
    end

    register :celluloid_pubsub, CelluloidPubsub
  end
end
