# encoding: utf-8
# frozen_string_literal: true

# Returns the version of the gem  as a <tt>Gem::Version</tt>
module CelluloidPubsub
  #  it prints the gem version as a string
  #
  # @return [String]
  #
  # @api public
  # :nocov:
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end
  # :nocov:

  # module used to generate the version string
  # provides a easy way of getting the major, minor and tiny
  # :nocov:
  module VERSION
    # major release version
    # :nocov:
    MAJOR = 2
    # :nocov:

    # minor release version
    # :nocov:
    MINOR = 0
    # :nocov:

    # tiny release version
    # :nocov:
    TINY = 0
    # :nocov:

    # prelease version ( set this only if it is a prelease)
    # :nocov:
    PRE = nil
    # :nocov:

    # generates the version string
    # :nocov:
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
    # :nocov:
  end
  # :nocov:
end
