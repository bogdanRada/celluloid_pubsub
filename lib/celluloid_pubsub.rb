# encoding: utf-8
# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'celluloid/io'
require 'celluloid/websocket/client'
require 'active_support/all'
require 'json'
require 'thread'
require 'celluloid/pmap'
require 'celluloid_pubsub/base_actor'
require 'reel'
Gem.find_files('celluloid_pubsub/initializers/**/*.rb').each { |path| require path }
Gem.find_files('celluloid_pubsub/**/*.rb').each { |path| require path }
