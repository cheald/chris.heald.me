---
layout: post
title: Rails, Varnish, Cookie Sessions, and CSRF tokens
categories:
- Rails
tags:
- caching
- cookies
- csr
- Rails
- varnish
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '334778181'
---
<img src="http://www.coffeepowered.net/wp-content/uploads/2011/01/126070445_82ca5f6f4c_m.jpg" align="right" style="margin: 0 0 15px 15px;" alt="Cookies! Delicious and performance-shattering." />I've recently been trying to figure out how to get Rails to place nicely with <a href="http://varnish-cache.org/">Varnish</a>. It doesn't do that very well. In a nutshell:

* Varnish is easy to use, if your app isn't setting session cookies until you actually need them. The presence of a session cookie usually means that content shouldn't be cacheable.
* Hitting any page with a form results in Rails generating a CSRF token and sticking it in the session, generating a session cookie and effectively locking the rest of the session out of being cacheable (even if it should be).
* Just *breathing* the method `session` in your app initializes your session.
* The Rails cookie session middleware assumes you always want to write a session cookie.

Fortunately, since so much of this is in Rack middleware, we can fix its mistakes with a middleware of our own. In a nutshell, I'm going to:

* Avoid writing CSRF tokens until we actually need them
* Check and see if we have an "empty" session (ie, no interesting data, just the session ID)
* Prevent session cookies from being sent to the browser unless there's actually useful data in them.

Let's get started. There's a lot to this, and it's a delicate collection of hacks, but it works nicely.

<h2>The care and feeding of CSRF tokens</h2>

To get started, I disabled CSRF functionality based on user state. In your application_controller.rb:

~~~ruby
  protect_from_forgery :if => :user?
  skip_before_filter :verify_authenticity_token, :unless => :user?

protected

  def form_authenticity_token
    if user?
      session[:_csrf_token] ||= ActiveSupport::SecureRandom.base64(32)
    end
  end
~~~

In this case, `user?` is a method from my authentication framework that lets me check if I have an active session. The astute reader will note that this check performs the aforementioned breathing-on (and thereby initializing) the session, so it's unfortunately not quite as simple as this. However, this will prevent authenticity checks for unauthenticated sessions. There's no real point to them if you aren't performing privileged operations anyhow, so we'll just save the overhead.

<h2>Stuffing your cookies back into the jar</h2>

Next, we need to deal with the session cookie itself. We have two options when invalidating cookies - either strip them from the already-written headers, or just add another Set-Cookie line to instantly invalidate them. Since we're dealing with Varnish, we want option 1 - ideally, we won't be passing the Set-Cookie header, since Varnish (by default) won't cache any response that attempts to set a cookie.

Session cookie management happens in `ActionController::Session::CookieStore`, and it's really high up in the middleware stack. `rake middleware` will dump your stack - you'll find it's usually in position 2 or 3. So, in order to tweak it, we'll need to inject a new middleware into your stack to mess with your cookie headers after the cookie handler itself blindly writes them out.

Scroll down if you want the code, but the gist of it is this:

* Check for a special "cookie.logout" environment parameter. If this is present, we're going to just flat-out nuke the session cookie. More on this later.
* Otherwise, check to see if the session has any interesting keys. If it doesn't, remove it from the Set-Cookie header

The code itself. Drop this in `lib/strip_empty_sessions.rb`.

~~~ruby
class StripEmptySessions
  ENV_SESSION_KEY = "rack.session".freeze
  HTTP_SET_COOKIE = "Set-Cookie".freeze
  BOGUS_KEYS = [:session_id, :_csrf_token]

  def initialize(app, options = {})
    @app = app
    @options = options
  end

  def call(env)
    status, headers, body = @app.call(env)

    session_data = env[ENV_SESSION_KEY]
    sc = headers[HTTP_SET_COOKIE]
    if env["cookie.logout"]
      value = Hash.new
      value[:value] = "x"
      value[:expires] = Time.now - 1.year
      cookie = build_cookie(@options[:key], value.merge(@options))

      if sc.nil?
        headers[HTTP_SET_COOKIE] = cookie if env["cookie.logout"]
      elsif sc.is_a? Array
        sc << cookie if env["cookie.logout"]
      elsif sc.is_a? String
        headers[HTTP_SET_COOKIE] << "\n#{cookie}" if env["cookie.logout"]
      end
    elsif (session_data.keys - BOGUS_KEYS).empty?
      if sc.is_a? Array
        sc.reject! {|c| c.match(/^\n?#{@options[:key]}=/)}
      elsif sc.is_a? String
        headers[HTTP_SET_COOKIE].gsub!( /(^|\n)#{@options[:key]}=.*?(\n|$)/, "" )
      end
    end

    [status, headers, body]
  end

  private

  # Copied from the cookie session middleware.
  def build_cookie(key, value)
    case value
    when Hash
      domain  = "; domain="  + value[:domain] if value[:domain]
      path    = "; path="    + value[:path]   if value[:path]
      # According to RFC 2109, we need dashes here.
      # N.B.: cgi.rb uses spaces...
      expires = "; expires=" + value[:expires].clone.gmtime.
        strftime("%a, %d-%b-%Y %H:%M:%S GMT") if value[:expires]
      secure = "; secure" if value[:secure]
      httponly = "; HttpOnly" if value[:httponly]
      value = value[:value]
    end
    value = [value] unless Array === value
    Rack::Utils.escape(key) + "=" +
      value.map { |v| Rack::Utils.escape(v) }.join("&amp;") +
      "#{domain}#{path}#{expires}#{secure}#{httponly}"
  end
end
~~~

Next, you'll need to add this to your middleware stack. In your `environment.rb`:

~~~ruby
config.middleware.insert_before "ActionController::Session::CookieStore", "StripEmptySessions", :key => "your_session_key", :path => "/", :httponly => true
~~~

The `:key` and `:path` parameters should match your session cookie settings.

What this will do is let this middleware run on the way back up the stack, right after the session handler gets a crack at things. If there is nothing interesting in the session, it'll remove that line from the Set-Cookie header, so if you aren't setting any other cookies, the header should end up being empty and should get thrown away. If you triggered a logout, will invalidate the client cookies (rather than just writing a cookie with no data in it back to them).

To do that, you'll need to modify your logout method:

~~~ruby
def logout
  request.env["cookie.logout"] = true
end
~~~

That should be it. You should now:

1. Not be setting session cookies for empty sessions
1. Not be setting CSRF tokens for anonymous sessions
1. Not be leaving "empty" session cookies laying around on client machines after a logout.

The net result is that you should be cookieless for anonymous sessions, resulting in trivial caching with Varnish. This can vastly improve the performance of your site - especially if you're catching high-traffic pages from web crawlers and the like with Varnish, so they never touch your Rails stack.

<hr>

<i>Cookie image (C) <a href="http://www.flickr.com/photos/71217725@N00/126070445/sizes/z/">scubadive67</a>, used under Creative Commons license</i>
