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
    # major release version
    MAJOR = 0
    # minor release version
    MINOR = 5
    # tiny release version
    TINY = 1
    # prelease version ( set this only if it is a prelease)
    PRE = nil

    # generates the version string
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
