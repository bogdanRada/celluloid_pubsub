#!/usr/bin/env ruby
require "pathname"
bin_file = Pathname.new(__FILE__).realpath
# add self to libpath
$:.unshift File.expand_path("../../lib", bin_file)
require 'celluloid_pubsub/cli'

CelluloidPubsub::CLI.new(ARGV).run
