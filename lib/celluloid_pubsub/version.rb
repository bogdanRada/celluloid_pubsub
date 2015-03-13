# Returns the version of the gem  as a <tt>Gem::Version</tt>
module CelluloidPubsub
  #  it prints the gem version as a string
  #
  # @return [String]
  #
  # @api public
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  # module used to generate the version string
  # provides a easy way of getting the major, minor and tiny
  module VERSION
    MAJOR = 0
    MINOR = 0
    TINY = 5
    PRE = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
