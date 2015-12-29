require_relative './shared_classes'

CelluloidPubsub::WebServer.supervise_as(:web_server, enable_debug: true, use_redis: true)
Subscriber.supervise_as(:subscriber, enable_debug: true)
Publisher.supervise_as(:publisher, enable_debug: true)
sleep
