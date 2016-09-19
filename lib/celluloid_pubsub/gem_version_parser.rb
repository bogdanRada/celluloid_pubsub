# frozen_string_literal: true
module CelluloidPubsub
  # class used for parsing gem versions
  # @!attribute [r] version
  #   @return [String, Integer] version that needs parsing
  #
  # @!attribute [r] options
  #   @return [Hash] The additional options for parsing the version
  class GemVersionParser
    attr_reader :version
    attr_reader :options

    #  receives the version and the additional options
    #
    # @param  [String, Integer] version  the version that needs parsing
    # @param [Hash] options The additional options for parsing the version
    #
    # @return [void]
    #
    # @api public
    #
    # :nocov:
    def initialize(version, options = {})
      @version = version
      @options = options.is_a?(Hash) ? options : {}
    end

    #  parses the version and returns the version with a single decimal point by default
    # @return [Float]
    #
    # @api public
    def parsed_number
      return 0 if @version.blank?
      @version_array = @version.to_s.split('.')
      number_with_single_decimal_point if @version_array.size > 2
      @version_array.join('.').to_f
    end

    # pops from the version array elements until its size is 2
    # @return [void]
    #
    # @api public
    def number_with_single_decimal_point
      @version_array.pop until @version_array.size == 2
    end
  end
end
