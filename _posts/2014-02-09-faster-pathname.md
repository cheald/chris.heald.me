---
layout: post
title: "faster_pathname: Making Sprockets faster"
status: publish
type: post
published: true
---

Late last year, I was working on replacing the Sprockets pipeline for our internal developers with a Guard-based solution, as a means of improving the speed
of change/reload/test cycles we're all so familiar with. Using Guard to do our asset rebuilds was substantially faster, but I found that when I used Sprockets
to do asset lookups, things got a lot slower. This led to me digging around a bit and finding that [Pathname is excrutiatingly slow](https://github.com/sstephenson/sprockets/issues/506), and Sprockets leans on it
really heavily.

The Sprockets team decided to not fix the issue, but to instead just rely on Pathname less in the future. That's good, but it doesn't solve the problem that Sprockets is costing us many thousands of developer-hours _right now_. So I threw together a gem to fix it, instead.

[faster_pathname](http://rubygems.org/gems/faster_pathname) is a gem that just monkeypatches Pathname with faster-than-default behavior. It's primarily targeted at alleviating the issues that Sprockets tends to have, but it should result in a general performance improvement for anything that uses Pathname. I would have preferred that Sockets use a solution that subclassed Pathname with customized behavior, but since Sprockets doesn't seem to be changing any time soon, this is a quick path to a solution.

You can get the source at [GitHub](https://github.com/cheald/faster_pathname). It's very simple - just a couple of monkeypatches, and an isolated copy of the Ruby 1.9 and 2.0 pathname test suites. In my tests, it sped up Sprockets asset lookups by around 25%, and has a very noticable impact on page load times in development environments.

Please note that it does not currently pass the 1.8 pathname tests, but I've not yet investigated that as 1.8 is officially deprecated, and I'm not a big fan of writing new software for deprecated platforms. The build currently fails on JRuby, but its test failures are consistent with stock JRuby's test failures, so I'm confident in saying that it's equivalently functional there, too. We've been running these patches (in non-gem form) across our dev team for a few months now, and have been very happy with the results.

Try it out and let me know how it works for you.