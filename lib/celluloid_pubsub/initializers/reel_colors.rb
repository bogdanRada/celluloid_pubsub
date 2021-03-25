# encoding: utf-8
# frozen_string_literal: true

require 'reel/spy'
Reel::Spy::Colors.class_eval do
  alias_method :original_colorize, :colorize

  # :nocov:
  def colorize(_var, str)
    force_utf8_encoding(str)
  end
  # :nocov:

  # Returns utf8 encoding of the msg
  # @param [String] msg
  # @return [String] ReturnsReturns utf8 encoding of the msg
  # :nocov:
  def force_utf8_encoding(msg)
    msg.respond_to?(:force_encoding) && msg.encoding.name != 'UTF-8' ? msg.force_encoding('UTF-8') : msg
  end
  # :nocov:
end
