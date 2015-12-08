require_relative './shared_classes'

CelluloidPubsub::WebServer.supervise_as(:web_server, enable_debug: $debug_enable, use_redis: true)
Subscriber.supervise_as(:subscriber, enable_debug: $debug_enabled, use_redis: true)
Publisher.supervise_as(:publisher, enable_debug: $debug_enabled, use_redis: true)
sleep
