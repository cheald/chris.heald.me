---
layout: post
title: 'JRuby Performance: Exceptions are not flow control'
categories:
- JRuby
- Performance
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '334757643'
---
I started playing with JRuby tonight, and got my application up and running on it in under 10 minutes (kudos to the JRuby team!), but when I started measuring its performance, I was seriously unimpressed. This didn't quite line up with what I've read of JRuby, so I decided to do a little digging.

<h2>Exception to the rule</h2>

I hopped into #jruby and was fortunate enough to get to talk to <a href="http://twitter.com/#!/headius">headius</a> directly. He pointed me towards <a href="http://jira.codehaus.org/browse/JRUBY-5534?page=com.atlassian.jira.plugin.system.issuetabpanels%3Acomment-tabpanel#issue-tabs">problems with older versions of the i18n gem</a>, which got me thinking - perhaps there were other abuses of exceptions as flow control in my app. After using jconsole to measure my exceptions-per-request, I found that I was generating several hundred exceptions per request, which was imposing a significant slowdown on my requests. After a quick discussion, headius <a href="https://github.com/jruby/jruby/commit/041cc9c77a3ade4ac7c9130deaafa70ae2c2db79">committed a change to add logging switches for exceptions</a>. I was able to fire up my trinidad instance with logging switches:

~~~bash
jruby -Xlog.exceptions=true -Xlog.backtraces=true -Xlog.callers=true -S trinidad 2>&1 | grep "Backtrace generated" -A4
~~~

and I instantly had data at my disposal. The ugly areas became clear very quickly - <a href="https://github.com/jnicklas/carrierwave">CarrierWave</a>, <a href="http://mongomapper.com/">MongoMapper</a>, and surprisingly, <a href="http://haml-lang.com/">Haml</a> were my top offenders.

~~~bash
Haml:          117 exceptions
CarrierWave:   162 exceptions
MongoMapper:   114 exceptions
~~~

The stack traces themselves are easy to interpret, too:

~~~bash
Backtrace generated:
NameError: undefined local variable or method `_hamlout' for #<ActionView::Base:0x1af81d1c>
               eval at org/jruby/RubyKernel.java:1088
     block_is_haml? at /usr/local/rvm/gems/jruby-head/gems/haml-3.1.2/lib/haml/helpers.rb:543
  capture_with_haml at /usr/local/rvm/gems/jruby-head/gems/haml-3.1.2/lib/haml/helpers/action_view_mods.rb:90
~~~

This gave me an easy target:

~~~ruby
    def block_is_haml?(block)
      eval('_hamlout', block.binding)
      true
    rescue
      false
    end
~~~

What's happening here is the block is evaluated with just <code>_hamlout</code>, which throws a NameError if the variable doesn't exist in the block's binding context, and then the proper boolean is returned. However, this is a perfect example of exceptions as flow control - the question is "Does _hamlout exist in the block context?", and that's not best answered by a NameError. Ruby gives us <code>defined?</code> to check that sort of thing trivially, and more importantly, idiomatically. So, I can just rewrite that helper as:

~~~ruby
    def block_is_haml?(block)
      eval("!!defined?(_hamlout)", block.binding)
    end
~~~

This is both far more correct, and far faster.

<h2>Lies, Damn Lies, and Benchmarks</h2>

Let's try a quick benchmark to test the effects of each method:

~~~ruby
require 'benchmark'

block = Proc.new { }
TIMES = 100000

Benchmark.bmbm do |x|
  x.report("Rescue") do
    TIMES.times do
      eval("_hamlout", block.binding) rescue nil
    end
  end

  x.report("defined?") do
    TIMES.times do
      eval("!!defined?(_hamlout)", block.binding)
    end
  end
end
~~~

And results:

~~~bash
[chris@luna repos]$ rvm use ree
Using /usr/local/rvm/gems/ree-1.8.7
[chris@luna repos]$ ruby test.rb
Rehearsal --------------------------------------------
Rescue     0.070000   0.010000   0.080000 (  0.082649)
defined?   0.020000   0.000000   0.020000 (  0.022991)
----------------------------------- total: 0.100000sec

               user     system      total        real
Rescue     0.080000   0.000000   0.080000 (  0.082292)
defined?   0.030000   0.000000   0.030000 (  0.022384)
~~~

Avoiding extraneous exceptions is clearly better on MRI (3.6x faster using `defined?` rather than `NameError`), but 100k exception raises only imposes an extra 0.6 seconds of runtime on the test. Probably not worth fretting over to too great a degree, at least until other optimizations have been made.

Let's try JRuby:

~~~bash
[chris@luna repos]$ rvm use jruby-head
Using /usr/local/rvm/gems/jruby-head
[chris@luna repos]$ jruby --server --fast test.rb
Rehearsal --------------------------------------------
Rescue    11.145000   0.000000  11.145000 ( 11.097000)
defined?   0.599000   0.000000   0.599000 (  0.599000)
---------------------------------- total: 11.744000sec

               user     system      total        real
Rescue     9.758000   0.000000   9.758000 (  9.758000)
defined?   0.357000   0.000000   0.357000 (  0.357000)
~~~

Holy <em>crap</em>, now we're in interesting territory. Using `defined?` rather than letting exception handling do our dirty work for us is <em>27.3x faster</em>. As Headius explains:

<blockquote>
In JRuby 1.6, we moved to using JVM-level facilities for generating exception backtraces. These facilities are considerably more expensive than the artificial backtraces we had been maintaining before...not incredibly expensive, but not free or as cheap as they used to be by any means. If applications and libraries use exceptions for exceptional error cases, it's not a big deal.
</blockquote>

The message here is pretty clear - use exceptions for things that are exceptional, not for flow control of the normal program operation. It's worth noting that in the benchmark, there isn't a big stack trace to generate; in a Rails app, each exception is going to generate a stack trace scores of entries deep, further exacerbating the problem. This is a simple test, and a simple case, but it illustrates the point fairly clearly.

By using the new exception logging switch, I was able to, in about an hour, monkeypatch several of the libraries we were using to reduce my exceptions-per-request from 400 to 8. This had an extremely noticable impact on my page times, reducing my test action runtimes significantly. If you'd like to take a look at all the pieces I patched, <a href="http://pastie.org/private/tmvj7dlr2sosxceep9a">check this quick pastie</a>. I'm working on patches to submit to each of these projects; besides avoiding punching JRuby in the tenders, it also improves runtimes in MRI and REE Ruby VMs.

In all three libraries, exceptions were being used as flow control to answer "does this variable or method exist?", and in all three cases, the libraries are doing it wrong; Ruby gives us `defined?` and `respond_to?`, and if you mean "Is this variable defined?", why not ask "`defined? variable`" rather than "try to use this and hit the eject button if it doesn't work"?

Exceptions are for things like "The remote service returned a bad response", or "That string didn't parse as valid JSON", or "That file which you're trying to parse as an image isn't actually an image" - exceptional circumstances. Things that you don't expect. If you're using exceptions to answer a question, or as a poor-man's GOTO, you may want to reevaluate how you're using them.

<h2>JRuby as an exceptions-as-flow-control detector</h2>

It's worth noting as a quick side item here that the commit to JRuby tonight makes JRuby a fantastic tool for locating libraries that use the exceptions-as-flow-control antipattern in your Rails apps. I tried a number of approaches to monkeypatching `Exception` before Headius committed the change, none of which worked very well, but once I built jruby-head, I had every exeception trace in my application laid out before me. You might consider taking a crack at this on your own apps - you might like what you find.

Getting running is as easy as:

~~~bash
rvm install jruby-head --branch jruby-1_6
rvm use jruby-head
gem install bundler trinidad
bundle install
jruby -Xlog.exceptions=true -Xlog.backtraces=true -Xlog.callers=true -S trinidad 2>&1 | grep "Backtrace generated" -A4
~~~

In a matter if minutes, you'll have an abundance of stack traces to chew on at your leisure. Or, if you're lucky, you won't have much of anything at all. Good hunting!

<h2>To sum up:</h2>

This is flow control:

<a href="http://www.coffeepowered.net/wp-content/uploads/2011/06/steering-wheel.jpg"><img src="http://www.coffeepowered.net/wp-content/uploads/2011/06/steering-wheel.jpg" alt="" title="steering-wheel" width="300" height="304" class="aligncenter size-full wp-image-378" /></a>

This is exception handling:

<a href="http://www.coffeepowered.net/wp-content/uploads/2011/06/ejection-seat-af-acesii.jpg"><img src="http://www.coffeepowered.net/wp-content/uploads/2011/06/ejection-seat-af-acesii.jpg" alt="" title="ejection-seat-af-acesii" width="300" height="201" class="aligncenter size-full wp-image-377" /></a>

Make sure you're pressing the right button.
