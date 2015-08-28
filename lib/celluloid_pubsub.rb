require 'celluloid/current'
require 'celluloid/io'
require 'reel'
require 'celluloid/websocket/client'
require 'active_support/all'
require 'celluloid_pubsub/config'
CelluloidPubsub::Config.backward_compatible
Gem.find_files('celluloid_pubsub/**/*.rb').each { |path| require path }
