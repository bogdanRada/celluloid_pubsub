require_relative './shared_classes'

CelluloidPubsub::WebServer.supervise_as(:web_server, enable_debug: $debug_enabled)
Subscriber.supervise_as(:subscriber, enable_debug: $debug_enabled)
Publisher.supervise_as(:publisher, enable_debug: $debug_enabled)
sleep
