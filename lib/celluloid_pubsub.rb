require 'rubygems'
require 'bundler'
require 'bundler/setup'
require 'celluloid/io'
require 'reel'
require 'celluloid/websocket/client'
require 'active_support/all'
require 'json'
require 'thread'
require 'celluloid/pmap'
require 'celluloid_pubsub/base_actor'
Gem.find_files('celluloid_pubsub/initializers/**/*.rb').each { |path| require path }
Gem.find_files('celluloid_pubsub/**/*.rb').each { |path| require path }
