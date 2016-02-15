celluloid_pubsub
================

[![Gem Version](https://badge.fury.io/rb/celluloid_pubsub.svg)](http://badge.fury.io/rb/celluloid_pubsub) [![Build Status](https://travis-ci.org/bogdanRada/celluloid_pubsub.png?branch=master,develop)](https://travis-ci.org/bogdanRada/celluloid_pubsub) [![Coverage Status](https://coveralls.io/repos/bogdanRada/celluloid_pubsub/badge.svg?branch=master)](https://coveralls.io/r/bogdanRada/celluloid_pubsub?branch=master) [![Code Climate](https://codeclimate.com/github/bogdanRada/celluloid_pubsub/badges/gpa.svg)](https://codeclimate.com/github/bogdanRada/celluloid_pubsub) [![Repo Size](https://reposs.herokuapp.com/?path=bogdanRada/celluloid_pubsub)](https://github.com/bogdanRada/celluloid_pubsub) [![Gem Downloads](https://ruby-gem-downloads-badge.herokuapp.com/celluloid_pubsub?type=total&style=dynamic)](https://github.com/bogdanRada/celluloid_pubsub) [![Documentation Status](https://inch-ci.org/github/bogdanRada/celluloid_pubsub.svg?branch=master)](https://inch-ci.org/github/bogdanRada/celluloid_pubsubb) [![Analytics](https://ga-beacon.appspot.com/UA-72570203-1/bogdanRada/celluloid_pubsub)](https://github.com/bogdanRada/celluloid_pubsub)

Description
-----------

CelluloidPubsub is a simple ruby implementation of publish subscribe design patterns using celluloid actors and websockets, using Celluloid::Reel server

Starting with version 0.4.0, Redis support was added [courtesy of em-hiredis](https://github.com/mloughran/em-hiredis)

Requirements
------------

1.	[Ruby 1.9.x or Ruby 2.x.x](http://www.ruby-lang.org)
2.	[Celluloid >= 0.16.0](https://github.com/celluloid/celluloid)
3.	[Celluloid-IO >= 0.16.2](https://github.com/celluloid/celluloid-io)
4.	[Reel >= 0.6.0](https://github.com/celluloid/reel)
5.	[http >= 1.0.2](https://github.com/httprb/http)
6.	[Celluloid-websocket-client = 0.0.1](https://github.com/jeremyd/celluloid-websocket-client)
7.	[ActiveSuport >= 4.2.0](https://rubygems.org/gems/activesupport)
8.	[em-hiredis >= 0.3.0](https://github.com/mloughran/em-hiredis)
9.	[json >= 1.8.3](https://github.com/flori/json)

Compatibility
-------------

Rails >3.0 only. MRI 1.9.x, 2.x, JRuby (--1.9).

Ruby 1.8 is not officially supported. We will accept further compatibilty pull-requests but no upcoming versions will be tested against it.

Rubinius support temporarily dropped due to Rails 4 incompatibility.

Installation Instructions
-------------------------

Add the following to your Gemfile:

```ruby
  gem "celluloid_pubsub"
```

Please read [Release Details](https://github.com/bogdanRada/celluloid_pubsub/releases) if you are upgrading. We break backward compatibility between large ticks but you can expect it to be specified at release notes.

Usage
-----

Creating a websocket server is simple as doing this. This are all the options available with their default values.

```ruby
CelluloidPubsub::WebServer.supervise_as(:web_server,
  enable_debug: true, # if debug messages should be logged
  use_redis: false ,  # if set to true, will instantiate a RedisReactor class to handle each connection, which requires Redis to be available. Otherwise will use a simple Reactor to handle the connections which  has no dependencies .
  log_file_path: "path/to/log_file.log", # The log file where all debugging information will be printed
  hostname: "0.0.0.0", # the hostname of the server.
  port: 1234, # the port on which the server will listen for connections
  path: '/ws', # the relative path used in the URL where connections are allowed to connect
  spy: false, # whether to spy all internal Websocket connections in order to get more debugging information
  backlog: 1024 # the number of connections allowed to be connected to the server at a certain time
 )
```

Creating a client is simple as doing this. If you provide the channel when you initialize the **CelluloidPubsub::Client** it will automatically start the subscription to that channel. But sometimes, you might want to subscribe at a later time, so you can just omit the channel when you initialize the client, and use instead **@client.subscribe('test_channel')**. After the subscription has started, the client must implement the method **on_message** and the **on_close** method (called when client disconnects from the channel). The method **on_message** will receive all incoming messages from the server. You can test if the subscription was successful by doing this **@client.succesfull_subscription?(message)**.

```ruby
class MyAwesomeClient
  include Celluloid
  include Celluloid::Logger

  def initialize(options = {})
    @client = CelluloidPubsub::Client.new({
      actor: Actor.current,
      channel: 'test_channel', # the channel to which this client will subscribe to.
      log_file_path: "path/to/log_file.log", # The log file where all debugging information will be printed
       hostname: "0.0.0.0",  # the hostname of the server.
       port: 1234,# the port on which the connection will be made to
       path: '/ws', # the relative path used in the URL where the connection will be connecting to
       enable_debug: false # if debug messages should be logged
     }.merge(options))
  end

  def on_message(message)
    if @client.succesfull_subscription?(message)
      puts "subscriber got successful subscription #{message.inspect}"
      @client.publish('test_channel2', 'data' => ' subscriber got successfull subscription') # the message needs to be a Hash
    else
      puts "subscriber got message #{message.inspect}"
    end
  end

  def on_close(code, reason)
    puts "websocket connection closed: #{code.inspect}, #{reason.inspect}"
    terminate
  end


end

```

The methods available that the **CelluloidPubsub::Client** instance can execute are:

-	subscribe -- subscribe - accepts a string as a channel name
-	publish - accepts a string as a channel name, and a Hash object
-	unsubscribe - accepts a string as a channel_name from which the client will unsubscribe from
-	unsubscribe_clients - accepts a string as a channel_name . This will disconnect all clients that are subscribed to that channel.
-	unsubscribe_all - This does not have any parameters. Will unsubscribe all clients from all channnels
-	on_close - This accepts a code and a reason as parameters. This method will be called when the client disconnects from the channel.

Examples
--------

Please check the [Examples Folder](https://github.com/bogdanRada/celluloid_pubsub/tree/master/examples). There you can find some basic examples.

Testing
-------

To test, do the following:

1.	cd to the gem root.
2.	bundle install
3.	bundle exec rake

Contributions
-------------

Please log all feedback/issues via [Github Issues](http://github.com/bogdanRada/celluloid_pubsub/issues). Thanks.

Contributing to celluloid_pubsub
--------------------------------

-	Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
-	Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
-	Fork the project.
-	Start a feature/bugfix branch.
-	Commit and push until you are happy with your contribution.
-	Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
-	Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

== Copyright

Copyright (c) 2015 bogdanRada. See LICENSE.txt for further details.
