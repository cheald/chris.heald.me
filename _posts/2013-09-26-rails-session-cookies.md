---
layout: post
title: No, Rails' CookieStore isn't broken
status: publish
type: post
published: true
---

A post recently hit the Full Disclosure seclist titled "[Move away from CookieStore if you care about your users and their security](http://seclists.org/fulldisclosure/2013/Sep/145)". The post discusses a property of session cookies - notably, that hitting "logout" doesn't prevent a cookie from being reused to regain that session later, since if someone manages to jack one of your users' cookies, they can just replay that cookie again at any time and gain access to the users' account.

It's worth first noting that *this vulnerability requires your user's session cookies to be compromised* in the first place, so the whole vulnerability hinges on with "if your user is already owned, then..."

That said, yes, if you use sessions naively, then a compromised cookie may be used to gain access to a user's account so long as the application's session secret hasn't changed (thereby invalidating the cookie signature). Note that this is true for *all* session stores, though in the case of serverside sessions, this only holds until the session gets swept (which may happen on explicit logout, but does not necessarily happen at a defined time otherwise); presuming you have some kind of session TTL in play, an attacker could keep their jacked session ID active indefinitely there, as well. A hijacked session cookie is Bad News (which is why you should be using HTTPS and HTTPS-only cookies!) no matter how you slice it.

Fortunately, if you're worried about this class of attack, mitigating it is Pretty Darn Simple.

If you just want parity with serverside session stores that just perform expired session sweeps, then you can enforce a TTL on a session by just providing a TTL value in the session, and validating that when the session is read, then updating it when the session is written. You could do this trivially with a Rack middleware, or if you just want it in your app:

~~~ruby
class ApplicationController
  before_filter :validate_session_timestamp
  after_filter  :persist_session_timestamp

  SESSION_TTL = 48.hours
  def validate_session_timestamp
    if user? && session.key?(:ttl) && session[:ttl] < SESSION_TTL.ago
      reset_session
      current_user = nil
      redirect_to login_path
    end
  end

  def persist_session_timestamp
    session[:ttl] = Time.now if user?
  end
end
~~~

That's it. Any session that hasn't been touched in 48 hours won't validate and will get tossed out, same as serverside sessions (and as a bonus, you don't have to do any session sweeping yourself! Hooray!) This does leave the cookie vulerable to TTL refreshes, so perhaps you want something more robust.

Something that neither CookieStore or server-side stores can do by default is maintain a list of sessions associated with a given user, and provide the user a means to revoke access granted to previously-granted sessions. Consider the case where you walk away from a public computer having forgotten to hit "log out" - you have no means of invalidating that session from another computer. This is a problem!

Fortunately, it's trivial enough to just save a list of active sessions if desired:

~~~ruby
class User
  # Presume an active_sessions field on the model that is large enough to hold some list of sessions:
  serialize :active_sessions, Array

  def activate_session(id)
    active_sessions.push id unless active_sessions.include? id
    save
  end

  def deactivate_session(id)
    active_sessions.delete id
    save
  end
end

class SessionsController
  def login
    # ...
    current_user.activate_session session[:session_id]
  end

  def logout
    current_user.deactivate_session session[:session_id]
    reset_session
    # ...
  end
end

class ApplicationController
  before_filter :validate_active_session

  def validate_active_session
    if user? && !current_user.active_sessions.include? session[:session_id]
      reset_session
      redirect_to login_path
    end
  end
end
~~~

You could get more complex with this and save things like the last IP and geolocation that each session was active from, and present that to the user, GMail-style. You could enforce a maximum number of sessions that can be active at any given time. This makes it easy to let users log out other sessions:

~~~ruby
class User
  def expire_sessions!(active)
    self.active_sessions = [active]
    save
  end
end

class UserController
  def logout_other_sessions
    current_user.expire_sessions! session[:session_id]
    # Redirect or whatever
  end
end
~~~

This technique is applicable to *all* session stores, not just CookieStore (you won't be able to get a list of sessions for a given user ID by default in ActiveRecordStore or whatever other serverside store you might want to use). You can give your users proactive control over their account security, and keep using CookieStore with all its benefits (like being invulnerable to session fixation!)