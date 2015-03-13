module CelluloidPubsub
  # class used to register new channels and save them in memory
  class Registry
    include ActiveSupport::Configurable
    class << self
      attr_accessor :channels
    end
    @channels = []
  end
end
