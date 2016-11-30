---
layout: post
title: Eight tips for getting the most out of your Rails app
categories:
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '334843684'
---
Rails does an awful lot to optimize page generation, but there are a number of hacks, tweaks, and usage patterns you should be using to get the most out of your app.

<h2>Configuration tweaks</h2>

There's a lot of the Rails stack that's written in Ruby, which is great - it's portable, it's flexible, it works out of the box. Unfortunately, for some things, this also means it's slow. Other times, pieces of the framework aren't implemented as optimally as they could be. What if you could improve your app's performance just by installing a few gems and tweaking a few config parameters? Good news - it's not hard.

<h3>1. Replace REXML with LibXML</h3>
By default, Rails uses a Ruby-native XML library called REXML. REXML is slow. REXML is very slow. REXML is personally responsible for me almost entirely giving up on Ruby due to a bad encounter with it in my first Ruby project. Fortunately, Rails provides a very easy way to avoid using REXML.

    gem install libxml-ruby

Then, in your app's config/environment.rb

    ActiveSupport::XmlMini.backend = 'LibXML'

That's it. Now, Rails will use the very lean, very fast libxml to parse XML documents, rather than the very fat, very slow REXML. If you're doing feed parsing, Hash.from_xml, or anything of that nature, this will save you massive amounts of pain.

<h3>2. <a href="http://slim-attributes.rubyforge.org/">slim_attributes</a></h3>

If you're using MySQL, there's no reason why you shouldn't be using slim_attributes.

> Slim Attributes boosts speed in Mysql/Rails ActiveRecord Models by avoiding instantiating Hashes for each result row, and lazily instantiating attributes as needed.

Pretty self-explanatory. Rather than creating massive hashes of everything the DB gives you, slim_attributes causes ActiveRecord to only create ruby objects when you actually ask for them in code. This can reduce both your app's memory usage and time spent on database queries. It's not a massive increase, but given that it takes exactly one line of code to add to your project, there's no reason not to use it.

<h3>3. <a href="http://github.com/sdsykes/slim_scrooge">slim_scrooge</a></h3>

From the developers of slim_attributes comes another drop-in database optimization.
<blockquote>SlimScrooge is an optimization layer to ensure your application only fetches the database content needed to minimize wire traffic, excessive <span>SQL</span> queries and reduce conversion overheads to native Ruby types.

SlimScrooge implements inline query optimisation, automatically restricting the columns fetched based on what was used during previous passes through the same part of your code.</blockquote>
Make your ORM work for you! By only fetching the content you need from your database, you reduce over-the-wire overhead, CPU overtime due to type conversion, and other such niceties. Again, just install the gem, require it in your project, and you're off to the races.

<h3>4. <a href="http://fast-xs.rubyforge.org/">fast_xs</a></h3>

By default, string escaping in Rails happens in native Ruby code. This is slow. We don't like slow. This is particularly prominent in areas like Builder::XmlMarkup, which you are using if you have any templates like `foo.xml.builder` lying around.

In modestly-sized document, this can result in pretty substantial slowdown in view construction. Rather than re-hashing what others have already done, I'll point you at <a href="http://samsaffron.com/archive/2008/03/29/Speed+up+your+feed+generation+in+rails">Speed up your feed generation in Rails</a> for the long and short on it all. This can result in builder views running upwards of 10x as fast, and all you have to do is install the fast_xs gem - Rails will automatically detect and patch it in if it's on the system.

<h3>5. <a href="http://www.kuwata-lab.com/erubis/">Erubis</a></h3>

<img src="http://www.coffeepowered.net/wp-content/uploads/2009/12/erubis01.png" alt="Erubis benchmarks" title="Erubis benchmarks" width="351" height="262" class="alignright size-full wp-image-213" /> Erubis is an ERB implementation written in C, rather than in Ruby. As a result, it parses ERB templates very, very quickly. In fact, the Erubis benchmarks up it at upwards of 3x faster than the native ERB implementation. Installation is easy - just check the <a href="http://www.kuwata-lab.com/erubis/users-guide.05.html">using Erubis with Ruby on Rails guide</a> and you're off to the races.

Do note that if you're entirely using <a href="http://haml-lang.com/">Haml</a> or similar, Erubis won't do much for you. Erubis is much faster than Haml, but Haml is much prettier than ERB. What you end up using is up to you!

<h2>Reduce action runtimes</h2>

<h3>6. Use <a href="http://github.com/tobi/delayed_job">delayed_job</a></h3>
Sometimes in the course of any web service, you run into some action that takes a little while to process. This is generally a pain and causes a whole host of problems, including frustrated users clicking refresh and spawning a dozen instances of your app all running the same long-running request and tying up valuable request slots. Long-running jobs, or jobs that absolutely must succeed are something of a royal pain in the patootie to handle gracefully. Fortunately, there's DelayedJob, which is much like a double shot of Codine to ease that terrible pain.

The concept is pretty simple - rather than immediately executing a long-running task, you create a "job" for it, then use an asynchronous daemon to run your job for you.

For example, let's say that your app wants to post to Twitter when you accomplish some task. This is all well and good if Twitter is up (ha!) and fast and isn't experiencing any technical issues and you aren't having any issues on your end and you don't have any exceptions. In short, it's fine when things don't break, but we all know that things break and go wrong and generally end up sideways when you're ever dealing with any kind of I/O, particularly of the remote web service kind. Rather than trying to post to Twitter in-process, we'll create a job whose task is to post to Twitter.

Install the delayed_job gem, create the delayed_jobs table as indicated in its documentation, and write your first worker.

~~~ruby
module Jobs
	class PostToTwitter < Struct.new(:username, :password, :tweet)
		def perform
			auth = Twitter::HTTPAuth.new(username, password)
			client = Twitter::Base.new(auth)
			client.update(tweet)
		end
	end
end
~~~

Now, in your controller code, or after_create in your model, or where ever, rather than posting to Twitter directly, just enqueue a job:

~~~ruby
Delayed::Job.enqueue Jobs::PostToTwitter.new(params[:username], params[:password], params[:tweet])
~~~

Finally, you'll want to fire up a DelayedJob daemon. This is pretty easy to do under Rails.

Create a file called `script/worker.rb` and stick the following in it:

~~~ruby
#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'
dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))

daemon_options = {
  :multiple =>; false,
  :dir_mode => :normal,
  :dir => File.join(dir, 'tmp', 'pids'),
  :backtrace => true
}

Daemons.run_proc('job_runner', daemon_options) do
  if ARGV.include?('--')
    ARGV.slice! 0..ARGV.index('--')
  else
    ARGV.clear
  end

  Dir.chdir dir
  RAILS_ENV = ARGV.first || ENV['RAILS_ENV'] || 'development'
  require File.join('config', 'environment')

  Delayed::Worker.new.start
end
~~~

Now, all you have to do is call `script/worker start` and you're up and running. Jobs will automatically be processed as they're added to the queue. If they fail, the reason why will be logged and the job will be scheduled to be retried in the future. You can correct any mistakes and re-run the job and watch it happily succeed. If the mistake is on the remote end, then the worker will keep retrying it until it succeeds, and your user doesn't have to sit there and wait while your app continually receives the API equivalent of the failwhale. Everyone is happy (eventually!)

Once you start using DelayedJob, you'll find that there are lots of things you can do with it to smooth out your app's user-response speed. Processing user avatars or large file uploads, recomputing expensive queries (like a social graph update), talking to remote web services, or even sending emails can all be moved away from the realtime and into the background with total ease.

<h3>7. Use memcached</h3>

This should probably be tip #1. Good caching can make or break a project, and memcached is a fantastic method for managing your caching.

> Memcached is an in-memory key-value store for small chunks of arbitrary data (strings, objects) from results of database calls, API calls, or page rendering.

By default, Rails writes page and fragment cache bits to disk. This is slow, is difficult to clean up after, adds a lot of wear-and-tear to your disk, and is generally undesirable. It's used because it's easy. Memcached is a far better solution - it is very much a "giant hash table in the sky". Dump a value into memory, read it back out of memory later. It is extremely fast, and comes with some super dandy features like time-based expiration that disk caching just won't get you.

Implementation in Rails is easy. First, install both the memcached daemon and the memcache client. Second, in your environment file, add something like so:

~~~ruby
require_library_or_gem 'memcache'
config.cache_store = :mem_cache_store, ["localhost:11211"]
~~~

By default, memcached runs on port 11211. Point Rails at it with the above directives and restart your app and that's it. You're running on memcached. No more ugly disk sweeping, and you get some really nice features. You can add multiple servers to the :mem_cache_store, too, which is several flavors of awesome. The memcached client will do automatic cluster management and balancing, so you can share the same cache between any number of servers, rather than each server having to have its own copy of that cache. Sweet!

~~~ruby
<% cache("my_custom_fragment_name:#{@record_id}", :raw => true, :expires_in => 1.hour) do %>
	<%=render :partial => "some_expensive_partial", :object => @record %>
<% end %>
~~~

This is your standard fragment cache, but the `:raw` and `:expires_in` parameters are new.

`:raw` tells the Ruby memcached client to not marshal the content before sticking it in memcached. Since you're just storing a document fragment (that is, a string), marshaling a ruby string and then unmarshaling it when you want to read it back is both unnecessary and slow.

`:expires_in` sets a maximum lifetime for this fragment. If we generate a fragment, memcached will timestamp it, and then if we try to read it back, say, 90 minutes later, memcached will recognize "oh hey, this fragment is expired! Sorry, I don't have anything for you!". Our view will regenerate and re-cache that fragment, and for the next 60 minutes, rather than trying to regenerate that fragment any time that view is called, it'll just pull the cached copy from memcached.

If you need to ever flush your cache, it's as easy as just restarting memcached. That's it, really. In one fell swoop, you get faster caching (yay!), easier cache management (yay!), and a cache that can scale across multiple servers (double yay!)

<h3>8. Use etags</h3>

etags are a nifty little feature that are woefully under-used by most web developers. You can think of them as a fingerprint for a given page. Consider the following process:

<ol>
<li>I request a page for the first time. The app generates the page and sends me both a copy of the page and a small hash finger print.</li>
<li>I request the page a second time, and send the fingerprint of my cached copy back to the server.</li>
<li>The server compares the fingerprint I sent with the fingerprint of its latest copy of the page. If they match, it just sends back a `304 Not Modified` header and stops rendering</li>
</ol>

Sounds handy, right? Sure, and it's really easy to implement in Rails. Let's assume you have a `BlogController` which has a `show` method for showing a given blog post. You could use the following to implement etags:

~~~ruby
def show
	@post = BlogPost.find params[:id]
	@comments = @post.comments.paginate params[:page], 25
	return unless stale? :etag => [@post, @comments]
end
~~~

Wait, that's it? Yes, actually! What's happening there is Rails builds a fingerprint of the object(s) you the `:etag` parameter of the `stale?` method. If the objects don't change, then the etag doesn't change. This means that you would get different etags for the same blog post on a different page of comments (good!), or a different etag if a comment is added (good!) or a different etag if the post is edited (good!), but as long as those objects haven't changed since the user's last request of that action, the etag will be the same, and the action will stop running right there and tell the browser to just display its cached copy.

On heavily-trafficked pages that aren't easily customized on a global scale (for example, if you have custom per-user bits on the page that mean that you can't serve the same page to everyone), this is a really decent way to prevent excessive and wasteful application work. If you don't use the `stale?` method, Rails always assumes that the page is stale, and thus needs to be regenerated.

On something of a tangent, can also use `stale? :last_modified => @post.updated_at` to determine if a page is fresh or stale. However, this does have the drawback of not being compatible with pagination, or sorted views, or anything of that nature. By using etags, you can ensure that each unique data set gets its own etag, and thus, doesn't have cache collisions.
