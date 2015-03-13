Caphub
==================


[![Gem Version](https://badge.fury.io/rb/celluloid_pubsub.svg)](http://badge.fury.io/rb/celluloid_pubsub)
[![Build Status](https://travis-ci.org/bogdanRada/celluloid_pubsub.png?branch=master,develop)](https://travis-ci.org/bogdanRada/celluloid_pubsub)
[![Coverage Status](https://coveralls.io/repos/bogdanRada/celluloid_pubsub/badge.svg?branch=master)](https://coveralls.io/r/bogdanRada/celluloid_pubsub?branch=master)
[![Code Climate](https://codeclimate.com/github/bogdanRada/celluloid_pubsub/badges/gpa.svg)](https://codeclimate.com/github/bogdanRada/celluloid_pubsub)
[![Repo Size](https://reposs.herokuapp.com/?path=bogdanRada/celluloid_pubsub)](https://github.com/bogdanRada/celluloid_pubsub)
[![Gem Downloads](https://ruby-gem-downloads-badge.herokuapp.com/celluloid_pubsub?type=total&style=dynamic)](https://github.com/bogdanRada/celluloid_pubsub)
[![Documentation Status](https://inch-ci.org/github/bogdanRada/celluloid_pubsub.svg?branch=master)](https://inch-ci.org/github/bogdanRada/celluloid_pubsubb)
[![Maintenance Status](http://stillmaintained.com/bogdanRada/celluloid_pubsub.png)](https://github.com/bogdanRada/celluloid_pubsub)

Description
--------
CelluloidPubsub is a simple ruby implementation of publish subscribe design patterns using celluloid actors and websockets, using Celluloid::Reel server

Requirements
--------
1.  [Ruby 1.9.x or Ruby 2.x.x][ruby]
3. [Celluloid >= 0.16.0][celluloid]
3. [Celluloid-IO >= 0.16.2][celluloid-io]
4. [Reel >= 0.5.0][reel]
5. [Celluloid-websocket-client = 0.0.1][celluloid-websocket-client]
6. [ActiveSuport >= 4.2.0][activesupport]

[ruby]: http://www.ruby-lang.org
[celluloid]: https://github.com/celluloid/celluloid
[celluloid-io]: https://github.com/celluloid/celluloid-io
[reel]: https://github.com/celluloid/reel
[celluloid-websocket-client]: [https://github.com/jeremyd/celluloid-websocket-client
[activesupport]:https://rubygems.org/gems/activesupport

Compatibility
--------

Rails >3.0 only. MRI 1.9.x, 2.x, JRuby (--1.9).

Ruby 1.8 is not officially supported. We will accept further compatibilty pull-requests but no upcoming versions will be tested against it.

Rubinius support temporarily dropped due to Rails 4 incompatibility.

Installation Instructions
--------

Add the following to your Gemfile:
  
```ruby
  gem "celluloid_pubsub"
```
Please read  [Release Details][release-details] if you are upgrading. We break backward compatibility between large ticks but you can expect it to be specified at release notes.
[release-details]: https://github.com/bogdanRada/celluloid_pubsub/releases

Examples
--------
Please check  the   [Examples Folder][examples]. There you can find some basic examples.

[examples]: https://github.com/bogdanRada/celluloid_pubsub/tree/master/examples
  
 Testing
--------

To test, do the following:

1. cd to the gem root.
2. bundle install
3. bundle exec rake

Contributions
--------

Please log all feedback/issues via [Examples Folder][issues].  Thanks.

[issues]: http://github.com/bogdanRada/celluloid_pubsub/issues

Contributing to celluloid_pubsub
--------

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

== Copyright

Copyright (c) 2015 bogdanRada. See LICENSE.txt for
further details.
