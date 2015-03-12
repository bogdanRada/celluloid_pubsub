module CelluloidPubsub # Returns the version of the currently loaded Rails as a <tt>Gem::Version</tt>
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 0
    MINOR = 0
    TINY = 1
    PRE = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
