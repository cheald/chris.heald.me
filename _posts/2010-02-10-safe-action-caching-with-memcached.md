---
layout: post
title: Safe action caching with Memcached
categories:
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '335343016'
---
I've started using action caching more aggressively, to handle a large volume of not-signed-in search traffic. It composes a significant chunk of my site's total traffic, but there's no good reason to be recomputing full pages for all those long-tail hits. So, the obvious thing is to just implement a quick action cache.

~~~ruby
# Controller
caches_action :show, :unless => :user?, :expires_in => 24.hours

# Sweeper
expire_action :controller => "nodes", :action => "show", :id => record.to_param
~~~

This all works dandy, but I generate pretty URLs, which means sometimes there are characters in the URL that Memcached doesn't like. A few minutes after deploying my patch, I started getting IMs from my logger bot telling me things were unhappy.

    blippr. com: [#1265856785] ArgumentError: illegal character in key "views/m.blippr.com/apps/346562-PicFo g.mobile"
    blippr. com: [#1265857710] ArgumentError: illegal character in key "views/www.blippr.com/apps/336714-µTorrent  "
    blippr. com: [#1265857897] ArgumentError: illegal character in key "views/www.blippr.com/apps/337076-ustre am"
    blippr. com: [#1265857924] ArgumentError: illegal character in key "views/www.blippr.com/apps/336714-µTorrent  "

That's memcached complaining about the hash keys we're giving to it. This just won't do. We could just regex out "bad" characters, but that means potential collisions, and potentially leaves edge cases. Why not just hash it instead?

A quick monkey patch later:

~~~ruby
class ActionController::Caching::Actions::ActionCachePath
	def path
		@cached_path ||= Digest::SHA1.hexdigest(@path)
	end
end
~~~

And we're all dandy. Now, rather than caching by path, the path is hashed, and the hash is used as the path key. Since hashes will always be hexadecimal characters, we know that it'll never make memcached unhappy.

~~~ruby
Path is blippr.com/movies/6696-The-Silence-of-the-Lambs...
Cached fragment hit: views/9111cdefca4a52cb0e3a5ebac4f618127a30efd0 (1.1ms)
~~~

There is an argument for not using this technique if you're using file-based caching, since it means your cached bits won't be segregated into directories, but memcached doesn't support expiry by regex anyhow, so there's no good reason to not use it in this case.

Enjoy!
