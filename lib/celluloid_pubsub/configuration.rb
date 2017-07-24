module CelluloidPubsub
  class Configuration

    SETTINGS = [
      :secure,
      :host,
      :port,
      :path,
      :spy,
      :adapter,
      :debug_enabled,
      :log_file_path,
      :backlog
    ]

    SETTINGS.each do |setting|
      attr_reader setting
      attr_accessor setting
    end

    def initialize
      @secure         = true
      @host           = '0.0.0.0'
      # by default the port is  nil so that it will find itself
      # an unused port automatically
      @port           = nil
      @path           = '/ws'
      @spy            = false
      @adapter        = 'classic'
      @debug_enabled  = false
      @log_file_path  = nil
      @backlog        = 1024
    end

  end
end
