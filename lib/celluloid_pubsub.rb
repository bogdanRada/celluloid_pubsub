require 'rubygems'
require 'bundler'
require 'versionomy'
require 'celluloid_pubsub/backward_compatible'
require 'celluloid/io'
require 'reel'
require 'celluloid/websocket/client'
require 'active_support/all'
Gem.find_files('celluloid_pubsub/**/*.rb').each { |path| require path }
