celluloid_pubsub
================

[![Gem Version](https://badge.fury.io/rb/celluloid_pubsub.svg)](http://badge.fury.io/rb/celluloid_pubsub) [![Build Status](https://travis-ci.org/bogdanRada/celluloid_pubsub.png?branch=master,develop)](https://travis-ci.org/bogdanRada/celluloid_pubsub) [![Coverage Status](https://coveralls.io/repos/bogdanRada/celluloid_pubsub/badge.svg?branch=master)](https://coveralls.io/r/bogdanRada/celluloid_pubsub?branch=master) [![Code Climate](https://codeclimate.com/github/bogdanRada/celluloid_pubsub/badges/gpa.svg)](https://codeclimate.com/github/bogdanRada/celluloid_pubsub) [![Repo Size](https://reposs.herokuapp.com/?path=bogdanRada/celluloid_pubsub)](https://github.com/bogdanRada/celluloid_pubsub) [![Gem Downloads](https://ruby-gem-downloads-badge.herokuapp.com/celluloid_pubsub?type=total&style=dynamic)](https://github.com/bogdanRada/celluloid_pubsub) [![Documentation Status](https://inch-ci.org/github/bogdanRada/celluloid_pubsub.svg?branch=master)](https://inch-ci.org/github/bogdanRada/celluloid_pubsubb) [![Analytics](https://ga-beacon.appspot.com/UA-72570203-1/bogdanRada/celluloid_pubsub)](https://github.com/bogdanRada/celluloid_pubsub)

Description
-----------

CelluloidPubsub is a simple ruby implementation of publish subscribe design patterns using celluloid actors and websockets, using Celluloid::Reel server

Requirements
------------

1.	[Ruby 1.9.x or Ruby 2.x.x](http://www.ruby-lang.org)
2.	[Celluloid >= 0.16.0](https://github.com/celluloid/celluloid)
3.	[Celluloid-IO >= 0.16.2](https://github.com/celluloid/celluloid-io)
4.	[Reel >= 0.5.0](https://github.com/celluloid/reel)
5.	[Celluloid-websocket-client = 0.0.1](https://github.com/jeremyd/celluloid-websocket-client)
6.	[ActiveSuport >= 4.2.0](https://rubygems.org/gems/activesupport)

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
