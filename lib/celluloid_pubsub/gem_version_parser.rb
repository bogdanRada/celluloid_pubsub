# frozen_string_literal: true
module CelluloidPubsub
  # class used for parsing gem versions
  class GemVersionParser
    attr_reader :version

    def initialize(version, options = {})
      @version = version
      @options = options.is_a?(Hash) ? options : {}
    end

    def parsed_number
      return 0 if @version.blank?
      @version_array = @version.to_s.split('.')
      number_with_single_decimal_point if @version_array.size > 2
      @version_array.join('.').to_f
    end

    def number_with_single_decimal_point
      @version_array.pop until @version_array.size == 2
    end
  end
end
