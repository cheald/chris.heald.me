---
layout: post
title: Making HAML faster
categories:
- Performance
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '335222270'
---
Haml's among my favorite of the Rails technology stack. Clean, self-correcting templates that mean less typing and more doing for me. I love it.

Unfortunately, there have been a number of performance regressions introduced into Haml recently, and that sucks, because Rails spends a lot of time building views, and I'd really like those numbers to be smaller.

Over the past couple of weeks, I've been on-and-off profiling Haml and working on various performance patches. I mentioned one <a href="http://www.coffeepowered.net/2011/06/17/jruby-performance-exceptions-are-not-flow-control/">of them in my previous post</a> - avoiding exceptions as flow control. There are a couple more we need to watch out for, though.

<h2>Problem #1: Lots and lots of extra string parsing</h2>

There's a utility method that lets Haml compare the current version of Ruby with some arbitrary string, to find out if certain features are supported. You can look at the implementation of `version_gt`, if you'd like, but it's relatively complex, and we're invoking it a <em>lot</em> in any given template.

In <a href="https://github.com/nex3/haml/blob/master/lib/haml/util.rb#L268">`Haml::Util`</a>

~~~ruby
    def version_geq(v1, v2)
      version_gt(v1, v2) || !version_gt(v2, v1)
    end
~~~

Memoizing these values results in significantly less string parsing and much faster templates.

~~~ruby
    def version_geq(v1, v2)
      @@version_comparison_cache ||= {}
      k = "#{v1}#{v2}"
      return @@version_comparison_cache[k] unless @@version_comparison_cache[k].nil?
      @@version_comparison_cache[k] = ( version_gt(v1, v2) || !version_gt(v2, v1) )
    end
~~~

<h2>Problem #2: Extraneous block creation</h2>

<a href="https://github.com/nex3/haml/blob/master/lib/haml/compiler.rb#L444">`Haml::Compiler#compile`</a> is what compiles your Haml soup down into HTML.  It also creates a bunch of extra closures - one for every leaf tag in your document.

~~~ruby
    def compile(node)
      parent, @node = @node, node
      block = proc {node.children.each {|c| compile c}}
      send("compile_#{node.type}", &(block unless node.children.empty?))
    ensure
      @node = parent
    end
~~~

Let's just change that so that the block is only created and passed if there are children to iterate:

~~~ruby
    def compile(node)
      parent, @node = @node, node
      if node.children.empty?
        send("compile_#{node.type}")
      else
        send("compile_#{node.type}",  &proc {node.children.each {|c| compile c}} )
      end
    ensure
      @node = parent
    end
~~~

It's worth noting that I tried a compacted single-line send, but it seems faster to just check `#empty?` than to conditionally create the block and pass `&(block if block)`.

<h2>Problem #3: Exceptions as flow control</h2>
`Haml::Helpers` has a couple of instances where it checks for the presence of `_hamlout` in a block binding by just eval'ing `_hamlout` and catching `NameError` to discover that it doesn't exist. I've refactored that to use more idiomatic constructs.

~~~diff
@@ -337,7 +337,7 @@ MESSAGE
     # @yield [args] A block of Haml code that will be converted to a string
     # @yieldparam args [Array] `args`
     def capture_haml(*args, &block)
-      buffer = eval('_hamlout', block.binding) rescue haml_buffer
+      buffer = eval('if defined? _hamlout then _hamlout else nil end', block.binding) || haml_buffer
       with_haml_buffer(buffer) do
         position = haml_buffer.buffer.length

...	...
@@ -540,10 +540,7 @@ MESSAGE
     # @param block [Proc] A Ruby block
     # @return [Boolean] Whether or not `block` is defined directly in a Haml template
     def block_is_haml?(block)
-      eval('_hamlout', block.binding)
-      true
-    rescue
-      false
+      eval('!!defined?(_hamlout)', block.binding)
     end
~~~

<h2>Results</h2>

To test, I have my branch in `./haml` and the current origin master in `./haml-upstream`. I've also got a 900-line Haml template with no inline ruby (just a html2haml converted webpage) that I'm parsing to test with.

To test, I just include the appropriate library and run the benchmark.

~~~ruby
require 'haml/lib/haml'
#require 'haml-upstream/lib/haml'
require 'benchmark'

TIMES = 100
source = open("formatted_email.haml").read

Benchmark.bmbm do |x|
    x.report("Render time") do
        TIMES.times do
            engine = Haml::Engine.new source
            engine.render :ugly => true
        end
    end
end
~~~

<h3>REE-1.8.7-2011.03</h3>

Upstream:

    [chris@luna repos]$ ruby haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time   7.010000   0.770000   7.780000 (  7.777076)
    -------------------------------------- total: 7.780000sec

                      user     system      total        real
    Render time   6.990000   0.710000   7.700000 (  7.721977)

And my branch:


    [chris@luna repos]$ ruby haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time   5.180000   0.460000   5.640000 (  5.703304)
    -------------------------------------- total: 5.640000sec

                      user     system      total        real
    Render time   5.170000   0.450000   5.620000 (  5.621875)

Improvement: **+27% speedup**

<h3>JRuby 1.6.0</h3>

Upstream:

    [chris@luna repos]$ jruby --server haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time  13.254000   0.000000  13.254000 ( 13.254000)
    ------------------------------------- total: 13.254000sec

                      user     system      total        real
    Render time   6.183000   0.000000   6.183000 (  6.183000)

My branch:

    [chris@luna repos]$ jruby --server haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time  11.726000   0.000000  11.726000 ( 11.726000)
    ------------------------------------- total: 11.726000sec

                      user     system      total        real
    Render time   4.856000   0.000000   4.856000 (  4.856000)

Improvement: **+21.5% speedup**

<h3>Ruby MRI 1.9.2</h3>

Upstream:

    [chris@luna repos]$ ruby haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time   6.990000   0.610000   7.600000 (  7.599568)
    -------------------------------------- total: 7.600000sec

                      user     system      total        real
    Render time   6.920000   0.660000   7.580000 (  7.577772)

My branch:

    [chris@luna repos]$ ruby haml-bench.rb
    Rehearsal -----------------------------------------------
    Render time   5.110000   0.470000   5.580000 (  5.573496)
    -------------------------------------- total: 5.580000sec

                      user     system      total        real
    Render time   5.150000   0.440000   5.590000 (  5.577480)

Improvement: **+26.3% speedup**

<h2>Final Words</h2>

I've got an <a href="https://github.com/nex3/haml/pull/346">open pull request</a>, but it's been ignored thus far. Make some noise and get this pulled into master, so we can make Rails apps everywhere faster!
