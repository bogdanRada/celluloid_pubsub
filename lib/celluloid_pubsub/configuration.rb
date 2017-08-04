module CelluloidPubsub
  class Configuration

    SETTINGS = [
      :secure,
      :host,
      :port,
      :path,
      :spy,
      :adapter,
      :http_adapter,
      :log_file_path,
      :backlog,
      :quiet,
      :rackup
    ]

    SETTINGS.each do |setting|
      attr_reader setting
      attr_accessor setting
    end

    def initialize
      @secure         = false
      @host           = '0.0.0.0'
      # by default the port is  nil so that it will find itself
      # an unused port automatically
      @port           = nil
      @path           = '/ws'
      @spy            = false
      @adapter        = 'classic'
      @http_adapter   = 'classic'
      @log_file_path  = nil
      @backlog        = 1024
      @quiet          = true
      @rackup         = "config.ru"
    end
    
    def attributes
      hash = {}
      CelluloidPubsub::Configuration::SETTINGS.each do |ivar|
        attr_value = send(ivar.to_s)
        hash[ivar] = attr_value
      end
      hash
    end

  end
end
