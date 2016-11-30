---
layout: post
title: Things to do when upgrading to Rails 2.3
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '334863184'
---
I'm upgrading <a href="http://www.blippr.com">blippr</a> to Rails 2.3. Here are some of the things that had to be changed to upgrade:

### Switch the application entirely to LibXML for all its XML parsing needs

In `config/environment.rb`: Add the following

~~~ruby
ActiveSupport::XmlMini.backend = 'LibXML'
~~~

This means that the <a href="http://www.coffeepowered.net/2008/09/27/powerful-easy-dry-multi-format-rest-apis/">faster\_xml\_simple monkeypatch</a> is no longer needed. I don't think we're doing much else with XML on blippr, but it'll be nice to have libxml-backed parsing all around. I must not use REXML. REXML is the app-killer. REXML is the little-death that brings total obliteration.

### Fixes for will_paginate and SQL errors when counting records with a custom :select clause

Upgrade <a href="http://wiki.github.com/mislav/will_paginate">will_paginate</a>. Even after the upgrade, something about 2.3's named scope handling was still breaking my app. I have a named scope like so:

~~~ruby
  :select => "*, (blips.vote_score+2)/WEIGHT_FACTOR as weighted_score",
  :order => "weighted_score desc"
~~~

This was causing `.paginate` calls with this named scope to fail with an invalid SQL error. will_paginate should automatically clobber `:select` phrases before attempting to count records, but it wasn't. The solution is to specify a `:count` condition to my `.paginate` calls with the right select clause.

~~~ruby
Blip.best.paginate(:page => current_page, :per_page => 30, :count => {:select => "blips.id"})
~~~

In general, any paginate call with a `:select` specified seems to break. The `:count` clause fixes them.

### Upgrade my libmemcached plugin

A lot of the internal session stuff has changed. We use Evan Weaver's libmemcached client, and an <a href="http://github.com/cheald/libmemcached_store/tree/master">upgraded copy of 37signals' libmemcached store</a> for Rails. The plugin's been upgraded to work with 2.3, and provides a session store on top of the general Rails store.

Our caching config now looks something like this:

~~~ruby
GENERAL_CACHE_SERVERS = ["localhost:11211"]
GENERAL_CACHE_OPTIONS = {:untaint => true}
SESSION_CACHE_SERVERS = ["localhost:11212"]
SESSION_CACHE_OPTIONS = { :prefix_key => "session:blippr" }
SESSION_MEMCACHE_CLIENT = Memcached.new(SESSION_CACHE_SERVERS, SESSION_CACHE_OPTIONS)

config.cache_store = :libmemcached_store, GENERAL_CACHE_SERVERS, GENERAL_CACHE_OPTIONS
config.action_controller.session_store = :libmemcached_store
config.action_controller.session = {
  :cache => SESSION_MEMCACHE_CLIENT,
  :expires_after => 86400
}
~~~

Works great with libmemcached, with separate memcached instances for fragments and sessions (so that an over-populated fragment store won't start clobbering sessions).

### Update query parsing

I parse query parameters for some funky filtering. In 2.2.2 I used:

~~~ruby
ActionController::AbstractRequest.parse_query_parameters(query_string)
~~~

In 2.3, that becomes:

~~~ruby
Rack::Utils.parse_query(query_string)
~~~

That's about it for now, but as problems arise I'll be sure to add them.
