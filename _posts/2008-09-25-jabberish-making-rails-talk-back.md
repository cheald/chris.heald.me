---
layout: post
title: 'Jabberish: making Rails talk back'
categories:
- Rails
- Ruby
tags:
- drb
- google talk
- jabber
- Rails
- Ruby
- xmpp
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '342718983'
---
Ever wanted to do IM from Rails? <a href="http://code.google.com/p/xmpp4r-simple/">xmpp4r-simple</a> makes it really easy to talk to Jabber clients (such as <a href="http://www.google.com/talk/">Google Talk</a> users) from Ruby, but it's not quite a cut-and-dried solution for your Rails apps. Fortunately, there's <a href="http://github.com/cheald/jabberish/tree/master">Jabberish</a>.

Jabberish is a DRb-backed Jabber client designed for use in multi-server Rails apps. Just drop in the plugin, configure, start the daemon, and off you go.

Installation is painless, as you'd expect.

    script/plugin install git://github.com/cheald/jabberish.git

Jabberish calls in your code will fail silently if the Jabberish DRb process isn't running, so if the daemon goes missing, it won't bring your app crashing down around your shoulders - you just won't get IMs.

Once it's installed, it's very easy to get it up and running.

1. Pop open `config/jabberish.yml` and set your preferences as you best see fit.
2. run `rake jabberish:start` - this will start up your DRb daemon, and connect to your configured account to your Jabber network
3. Call Jabberish from your code!

    `JabberishAgent.deliver("your-email@gmail.com", "Hi there!")`

There are many potential applications. For example, to send yourself IMs when your app has an error, in application.rb:

    def rescue_action(e)
      # The third parameter is "throttle", which will cause Jabberish to refuse
      # to send the same message to a given recipient twice in a row
      msg = sprintf("[#%s] %s (%s)", Time.now.to_i, e, e.backtrace.first)
      JabberishAgent.deliver("your-email@gmail.com", msg, true)
    end

And lickety split, you're IMing error reports to yourself in realtime. I'm sure others will find much more interesting things to do with it!
