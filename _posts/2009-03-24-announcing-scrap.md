---
layout: post
title: Announcing Scrap
categories:
- Rails
- Ruby
tags:
- memory
- metal
- objectspace
- performance
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '336565364'
---
I do a lot of memory and garbage analysis on my Rails apps, and in upgrading to Rails 2.3, I discovered a practical use for the new <a href="http://weblog.rubyonrails.org/2008/12/17/introducing-rails-metal">Rails Metal</a> middleware. Dumping memory stats to my log was just sorta unreadable in a practical scenario, and was more or less entirely unusable in production. Fortunately, Metal provides a really easy way to output readable information to the browser without invoking the full Rails stack. (It's also an excuse to write a Metal endpoint because it's new and shiny, but that's beside the point.)

It's up at <a href="http://github.com/cheald/scrap/tree/master">github</a> - installation is dead easy (assuming you're on Rails 2.3+, of course) - just install the plugin, restart your app, and hit `[your url]/stats/scrap` in your browser. Bam, instant juicy memory goodness about your app at your fingertips.

You can use it to troubleshoot heap leaks - just run a few requests, hit your Scrap URL, and see what your deltas look like. Seeing a huge growth in a certain type of object? Chances are pretty good that you have a heap leak, and can start tracking it down.

The request history can help you locate certain actions that might be causing spikes in memory usage. It'll show the last N requests, along with memory and heap statistics before each request. If there's a consistent memory usage leap after a certain action, chances are that it's doing something naughty.

Want to get a bigger picture on what objects are hanging around? You can use the `config/scrap.yml` file to get Scrap to spit out more detailed reports on instances of a given class. There's full documentation on it in the README.

Anyhow, give it a shot, let me know what you think.
