# encoding: utf-8
# frozen_string_literal: true
require 'reel/spy'
Reel::Spy::Colors.class_eval do
  alias_method :original_colorize, :colorize

  def colorize(_n, str)
    force_utf8_encoding(str)
  end

  # Returns utf8 encoding of the msg
  # @param [String] msg
  # @return [String] ReturnsReturns utf8 encoding of the msg
  def force_utf8_encoding(msg)
    msg.respond_to?(:force_encoding) && msg.encoding.name != 'UTF-8' ? msg.force_encoding('UTF-8') : msg
  end
end
