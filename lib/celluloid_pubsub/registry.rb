module CelluloidPubsub
  class Registry
    include ActiveSupport::Configurable
    class << self
      attr_accessor :channels
    end
    @channels = []
  end
end
