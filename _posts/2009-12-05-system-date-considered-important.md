---
layout: post
title: System date considered important
categories:
- Rails
- Security
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _wp_old_slug: system-date-is-important-kiddos
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '334894596'
---
I've been slamming my head against the wall for the past two hours. I had an OAuth connection to a remote service working just dandy in development, but as soon as I tried to use that exact same code with the exact same config and exact same gems in production...I was getting "401 unauthorized" errors back from the remote service when attempting to get a request token.

After an extremely tedious series of debugger checks to make sure my OAuth signature was right, I decided to just edit the oauth gem on my production box and add a little debugging statement to dump the HTTP request to stdout. What I found was...surprising.

~~~ruby
>> OAuthConsumers::Netflix.new.consumer.get_request_token
opening connection to api.netflix.com...
opened
<- "POST /oauth/request_token HTTP/1.1\r\nAccept: */*\r\nConnection: close\r\nUser-Agent: OAuth gem v0.3.6\r\nAuthorization: OAuth oauth_nonce=\"E73sq4XMkG547EbuCB9GUfG4AtsjD2QFySwLPKj0tI\", oauth_callback=\"oob\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"1260049119\", oauth_consumer_key=\"xxxxxxxxxxxxx\", oauth_signature=\"QD5b5Oy8LFLvXWl%2B3R%2BQI0xlIcg%3D\", oauth_version=\"1.0\"\r\nContent-Length: 0\r\nHost: api.netflix.com\r\n\r\n"
-> "HTTP/1.1 401 Unauthorized\r\n"
-> "X-Lighty-Magnet-Uri-Path: /oauth/request_token\r\n"
-> "X-Mashery-Responder: proxyworker-i-e23bae8a.mashery.com\r\n"
-> "X-Mashery-Error-Code: ERR_401_TIMESTAMP_IS_INVALID\r\n"
-> "Content-Type: text/plain\r\n"
-> "Accept-Ranges: bytes\r\n"
-> "Content-Length: 20\r\n"
-> "Date: Sat, 05 Dec 2009 21:27:08 GMT\r\n"
-> "Server: Mashery Proxy\r\n"
-> "\r\n"
reading 20 bytes...
-> "Timestamp Is Invalid"
read 20 bytes
Conn close
OAuth::Unauthorized: 401 Unauthorized
        from /opt/ruby-enterprise-1.8.7-2009.10/lib/ruby/gems/1.8/gems/oauth-0.3.6/lib/oauth/consumer.rb:200:in `token_request'
        from /opt/ruby-enterprise-1.8.7-2009.10/lib/ruby/gems/1.8/gems/oauth-0.3.6/lib/oauth/consumer.rb:128:in `get_request_token'
        from (irb):1
~~~

Whoa there, there's some info that the OAuth gem wasn't giving back to me. "Timestamp is invalid." Well then, a quick check of system time, and...oh, hey, it turns out that my system has drifted to about 10 minutes fast. Easily corrected, at least.

~~~ruby
# ntpdate -b 0.centos.pool.ntp.org && service ntpd start
~~~

With that all done...

~~~ruby
>> OAuthConsumers::Netflix.new.consumer.get_request_token
opening connection to api.netflix.com...
opened
<- "POST /oauth/request_token HTTP/1.1\r\nAccept: */*\r\nConnection: close\r\nUser-Agent: OAuth gem v0.3.6\r\nAuthorization: OAuth oauth_nonce=\"YIh5R3CBtAicneNREF5ZUcX80kao1zqRLLA5u8bQWA\", oauth_callback=\"oob\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"1260048573\", oauth_consumer_key=\"ksfa9rxmb8dzkxg4npwr74zv\", oauth_signature=\"%2B%2Fyd5sRsJ7qmmZWNRqSlCvByYxw%3D\", oauth_version=\"1.0\"\r\nContent-Length: 0\r\nHost: api.netflix.com\r\n\r\n"
-> "HTTP/1.1 200 OK\r\n"
-> "X-Lighty-Magnet-Uri-Path: /oauth/request_token\r\n"
-> "X-Mashery-Responder: proxyworker-i-7c31a414.mashery.com\r\n"
-> "Content-Type: text/plain\r\n"
-> "Server: Mashery_Server_Adapter_Query\r\n"
-> "Date: Sat, 05 Dec 2009 21:29:32 GMT\r\n"
-> "Accept-Ranges: bytes\r\n"
-> "Content-Length: 194\r\n"
-> "\r\n"
reading 194 bytes...
-> "oauth_token=xxxxxxxx&oauth_token_secret=xxxxxxxxx&application_name=xxxxx&login_url=https%3A%2F%2Fapi-user.netflix.com%2Foauth%2Flogin%3Foauth_token%3Dczjsmzw74nk2wy274g6drmwt"
read 194 bytes
Conn close
~~~

All better. Keep those datetimes synched, sports fans. Web services are becoming more and more interconnected, and if there's one thing I've learned from heist movies, it's that the first step in any successful job is to make sure your watches are synchronized. Nobody likes that guy who shows up 10 minutes late to everything!
