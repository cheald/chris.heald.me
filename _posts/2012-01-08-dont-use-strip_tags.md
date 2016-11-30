---
layout: post
title: Don't use strip_tags.
categories:
- Performance
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '531856936'
  _wp_old_slug: dont-use-strip_tags-to-just-strip-tags
---
I ran into a rather surprising little problem earlier this week that I felt bore documenting. It turns out that the "simple" Rails <a href="http://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-strip_tags">strip_tags</a> helper is <i>massive</i> overkill when you just want to strip markup out of a document. It offers a lot of functionality, but it comes at a pretty ugly performance cost.

Here's the call graph for `#strip_tags` (as profiled in an application I'm working on). As you can see, it tokenizes the entire string, and then iterates the tokens, likely pushing and popping sections onto and off of a stack as tags are opened and closed.

![Call graph for strip_tags](/uploads/2012/01/strip_tags_call_graph.png)

This is a lot more than a quick little regex to strip out tags; it's actually parsing the full HTML document. Fortunately, there are already tools to do that, and they have their slow parts written as C extensions. <a href="http://nokogiri.org/">Nokogiri</a> is my weapon of choice in this regard - it's battle-tested and generally rocks at parsing markup, even when it's poorly-formed.

So, let's benchmark a "strip all the markup out of a string" use case with `#strip_tags` and nokogiri.

~~~ruby
require 'rubygems'
require 'action_view'
require 'nokogiri'

include ActionView::Helpers::SanitizeHelper

f = open("news").read

LOOPS = 1000
Benchmark.bmbm do |x|
  x.report("strip_tags") { LOOPS.times { strip_tags f }}
  x.report("nokogiri") { LOOPS.times { Nokogiri::HTML(f).text }}
end
~~~

The data file in this case is a snapshot of the current page of <a href="http://news.ycombinator.com/">Hacker News</a>. It's a 23kb HTML file. Nothing too huge, but certainly not small, either. Let's run it through the benchmark:

    [chris@luna projects]$ ruby strip.rb
    Rehearsal ----------------------------------------------
    strip_tags  33.070000   0.010000  33.080000 ( 33.092638)
    nokogiri     3.220000   0.020000   3.240000 (  3.241090)
    ------------------------------------ total: 36.320000sec

                     user     system      total        real
    strip_tags  33.010000   0.010000  33.020000 ( 33.056551)
    nokogiri     3.190000   0.000000   3.190000 (  3.200680)

Yikes. It's not just slower, it's ~10x slower.

Don't use `strip_tags`. Also, profile your code. But just because it's convenient doesn't mean you should use it.
