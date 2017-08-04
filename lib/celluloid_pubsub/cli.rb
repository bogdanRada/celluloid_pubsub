require 'celluloid_pubsub/all'
require 'optparse'

module CelluloidPubsub
  class CLI
    def initialize(argv)
      @argv   = argv
      @default_options = CelluloidPubsub.config.attributes
      parser
    end

    def parser
      @parser ||= OptionParser.new do |o|
        o.banner = "celluloid_pubsub <options> <rackup file>"

        o.on "-a", "--addr ADDR", "Address to listen on (default #{@default_options[:host]})" do |addr|
          @default_options[:host] = addr
        end

        o.on "-p", "--port PORT", "Port to bind to (default #{@default_options[:port]})" do |port|
          @default_options[:port] = port
        end

        o.on "-q", "--quiet", "Suppress normal logging output" do
          @default_options[:quiet] = true
        end

        o.on_tail "-h", "--help", "Show help" do
          STDOUT.puts @parser
          exit 1
        end
      end
    end

    def run
      @parser.parse! @argv
      @default_options[:rackup] = @argv.shift if @argv.last
      if @default_options[:rackup].present?  && File.exists?(File.expand_path(@default_options[:rackup]))
        app, options = ::Rack::Builder.parse_file(File.expand_path(@default_options[:rackup]))
        options.merge!(@default_options)
        ::Rack::Handler::CelluloidPubsub.run(app, options)

        Celluloid.logger.info "It works!"
      else
        Celluloid.logger.info "Missing file #{@default_options[:rackup]} !!!"
      end
    end
  end
end
