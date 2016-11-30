---
layout: post
title: Making MongoMapper 9x faster.
categories:
- MongoDB
- Performance
- Ruby
tags:
- mongomapper
- plucky
type: post
published: true
image:
  feature: 2013/07/mmfast.jpg
---

I've been doing some heavy work on [MongoMapper](https://github.com/jnunemaker/mongomapper) lately. It all started with a StackOverflow question, which led to a Rails developer user asking me what I thought of Mongoid vs MongoMapper. I've been using MM for ages, and was happy enough to offer a favorable opinion of it. But, I wanted to back up my assertions. I wrote a benchmark. It...was [disappointing](https://github.com/jnunemaker/mongomapper/pull/521).

This touched off a huge amount of work which resulted in some extremely large bugfixes, massive improvements to MM's document read speeds. Here's how it happened.

## Know Where You Come From

Initially, my goal was to prove the MongoMapper was approximately as fast at Mongoid at common use cases. I wrote a quick little benchmark, along the lines of this:

~~~ruby
class MMUser
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap

  key :name,      String
  key :age,       Integer
  key :birthday,  Date
  key :timestamp, Time
end

class MongoidUser
  include Mongoid::Document

  field :name,      type: String
  field :age,       type: Integer
  field :birthday,  type: Date
  field :timestamp, type: Time
end

LOOPS = 150

Benchmark.bm do |x|
  x.report "Mongomapper" do
    profile "mm" do
      LOOPS.times { MMUser.limit(200).all }
    end
  end

  x.report "Mongoid" do
    profile "mongoid" do
      LOOPS.times { MongoidUser.limit(200).to_a }
    end
  end
end
~~~

Nothing too fancy. But, imagine my dismay when I got the results:

~~~text
MongoMapper Read 150000     batches of 1000       64.250000   5.950000  70.200000 ( 70.786035)
    Mongoid Read 150000     batches of 1000        5.810000   0.580000   6.390000 (  6.499160)
~~~

Ouch. _Ouch_. MongoMapper isn't just slower, it's an order of magnitude slower. Time to dig in. What's going on?

## How I Learned To Stop Worrying And Love The Benchmark

One of my favorite tools for performance analysis is [kcachegrind](http://kcachegrind.sourceforge.net/html/Home.html). I use Windows as my desktop, and do my development on a headless Linux server. Fortunately, kcachegrind is cross-compiled for Windows. There's also a OS X equivalent called qcachegrind for the Mac users out there.

I cut the benchmark down a bit for the purposes of iteration, and added ruby-prof profiling. This gives us something like:

    Mongomapper 30.030000  21.560000  51.590000 ( 51.948948)

So now we know where we start - about 1730 microseconds per document load.

ruby-prof comes with support for cachegrind dumps baked in. I've written about it before, so I won't cover it here. Instead, let's just look at what kcachegrind says.

<img src="/uploads/2013/07/mm_before.png" />

I'm performing 150 loops and reading 200 documents apiece. Each document contains 5 keys (the 4 named plus _id), so I'd expect 5 * 150 * 200 = 150,000 calls to `write_key`. But instead, the first things I noticed were:

1. `read_key` is called 600,000 times (4x per document load)
2. `write_key` is called 300,000 times (2x per document load)

Surely we can improve that. That sounds like a good place to start.

MongoMapper uses a plugin architecture that starts with a basic implementation of a set of methods on each document, then allows plugins to override them and call `super` to add additional functionality. This is nice because it helps encourage good separation of concerns, and it makes it easy to treat functionality as separate modules for the purposes of debugging. Unfortunately, this also means that a given module might not only be running the code that it thinks it is.

MM does its document loads in [keys.rb](https://github.com/jnunemaker/mongomapper/blob/v0.12.0/lib/mongo_mapper/plugins/keys.rb#L271-280). This is pretty straightforward - it takes a hash of attributes, and for each attribute, calls a setter that sets the value and allows MM to do its typecasting magic. Easy, right?

Well, almost. Because of the plugin architecture, our "private" method `write_key` turns out to do an awful lot of work!

<img src="/uploads/2013/07/mm_write_tree.png" />

As you can see, `Keys` calls `[]=` which calls `Dirty#write_key`, which then `super` back to `Keys::write_key`. Let's go look at `Dirty#write_key`:

<img src="/uploads/2013/07/mm_write_tree2.png" />

Uh-oh. I think we found the source of our `read_key` calls. What's happening here is that MongoMapper's dirty attributes functionality overwrites `write_key` so that whenever a key is written, its old value is read (that's the `read_key` call), and is then compared to the value being written. If the values mismatch, then the field is marked dirty. But this is a database load! We don't need plugins to be able to modify and act on the data - we just want our data to be set on the document.

The solution I went with was to split this into an `internal_write_key` method and an overridable `write_key` method. When loading from the database, `Keys` is just concerned about getting the object populated. So, `load_from_database` now calls `internal_write_key`, and we changed `write_key` to do the same, so we have a consistent plugin interface, but bypass letting plugins get their hooks into the data as it's being read out of the DB.

~~~diff
--- a/lib/mongo_mapper/plugins/keys.rb
+++ b/lib/mongo_mapper/plugins/keys.rb
@@ -284,7 +284,7 @@ module MongoMapper
             if respond_to?(:"#{key}=") && !self.class.key?(key)
               self.send(:"#{key}=", value)
             else
-              self[key] = value
+              internal_write_key key, value
             end
           end
         end
@@ -300,6 +300,10 @@ module MongoMapper
         end

         def write_key(name, value)
+          internal_write_key(name, value)
+        end
+
+        def internal_write_key(name, value)
           key         = keys[name.to_s]
           as_mongo    = key.set(value)
           as_typecast = key.get(as_mongo)
~~~

Not too much, right? Let's see what it does to performance:

    Mongomapper 15.420000  10.530000  25.950000 ( 26.153595)

Not bad! Just cutting out the excessive reads and extra overhead due to `Dirty#write_key` improved our load time from 1730usec to 872usec - cutting our runtime in half. But we can do better!

Plucky 0.5.2 [had a bug in it](https://github.com/jnunemaker/plucky/pull/25) that would cause cursors to be iterated twice when reading. This basically meant that MM had to parse twice the data per document load. Let's relax the Plucky reference:

~~~diff
--- a/mongo_mapper.gemspec
+++ b/mongo_mapper.gemspec
@@ -15,5 +15,5 @@ Gem::Specification.new do |s|

   s.add_dependency 'activemodel',   '~> 3.0'
   s.add_dependency 'activesupport', '~> 3.0'
-  s.add_dependency 'plucky',        '~> 0.5.2'
+  s.add_dependency 'plucky',        '~> 0.5'
~~~

That brings us to:

    Mongomapper  8.080000   5.230000  13.310000 ( 13.426457)

Down to 443 usec per document load. Getting much better now!

<img src="/uploads/2013/07/mm_step_2.png" />

Looking at a fresh callgrind trace, we see that we're still spending a LOT of time in `write_key` (which we expect; this is a read-from-the-database test after all), but perhaps that can be optimized?

`write_key` is spending a lot of time in `Keys#set`. However, the reason that `Keys#write_key` calls `Key#set` is to cast the incoming value to a Mongo-friendly type. But, we know that we're already coming into this with a Mongo-friendly type! We'll add a parameter to `internal_write_key` that prevents it from trying to perform a cast in this case:

~~~diff
--- a/lib/mongo_mapper/plugins/keys.rb
+++ b/lib/mongo_mapper/plugins/keys.rb
@@ -274,7 +274,7 @@ module MongoMapper
             if respond_to?(:"#{key}=") && !self.class.key?(key)
               self.send(:"#{key}=", value)
             else
-              internal_write_key key, value
+              internal_write_key key, value, false
             end
           end
         end
@@ -305,11 +305,11 @@ module MongoMapper
           internal_write_key(name, value)
         end

-        def internal_write_key(name, value)
+        def internal_write_key(name, value, cast = true)
           key = keys[name.to_s]
           set_parent_document(key, value)
           instance_variable_set :"@#{name}_before_type_cast", value
-          instance_variable_set :"@#{name}", key.set(value)
+          instance_variable_set :"@#{name}", cast ? key.set(value) : value
         end
     end
   end
~~~

Our reward:

    Mongomapper  4.890000   3.560000   8.450000 (  8.531254)

Down to 284 usec/document!

We're out of obviously slow stuff, but let's keep looking. `Keys::ClassMethods#keys`, `Keys::#keys`, and `Keys::ClassMethods#key?` are cumulatively taking about 57 usec/document - about 20% of the total runtime!

<img src="/uploads/2013/07/mm_step_3.png" />

Looking in Keys::ClassMethods::key?

~~~ruby
def key?(key)
  keys.keys.include?(key.to_s)
end
~~~

Well, that won't do; Ruby provides a `key?` method on Hash already.

~~~ruby
--- a/lib/mongo_mapper/plugins/keys.rb
+++ b/lib/mongo_mapper/plugins/keys.rb
@@ -32,7 +32,7 @@ module MongoMapper
         end

         def key?(key)
-          keys.keys.include?(key.to_s)
+          keys.key? key.to_s
         end
~~~

    Mongomapper  4.720000   3.190000   7.910000 (  7.987447)

Another 22 usec/document gain.

We're making a lot of calls to the instance and class-level `#keys` methods. Perhaps those can be streamlined away.

(This was actually a much more involved change, but it's simplified for purposes here)

~~~diff
--- a/lib/mongo_mapper/plugins/keys.rb
+++ b/lib/mongo_mapper/plugins/keys.rb
@@ -270,8 +270,9 @@ module MongoMapper
       private
         def load_from_database(attrs)
           return if attrs.blank?
+          @__keys = self.class.keys
           attrs.each do |key, value|
-            if respond_to?(:"#{key}=") && !self.class.key?(key)
+            if respond_to?(:"#{key}=") && !@__keys.key?(key)
               self.send(:"#{key}=", value)
             else
               internal_write_key key, value, false
@@ -302,11 +303,12 @@ module MongoMapper
         end

         def write_key(name, value)
+          @__keys = self.class.keys
           internal_write_key(name, value)
         end

         def internal_write_key(name, value, cast = true)
-          key = keys[name.to_s]
+          key = @__keys[name.to_s]
           set_parent_document(key, value)
           instance_variable_set :"@#{name}_before_type_cast", value
           instance_variable_set :"@#{name}", cast ? key.set(value) : value
~~~

And results:

    Mongomapper  4.200000   2.700000   6.900000 (  7.009927)

Yet *another* 29 usec/document gain.

## In Closing

There were a number of other changes, refactorings, and improvements made, and even more tested and discarded, but the fundamental procedure remains the same - measure, use those measurements to find a line of attack, and improve. The test suites will help you discover if you've messed something up, and your benchmarking tools can help you improve your runtimes by finding and eliminating unnecessary code paths.

In the end, we ended up with something like this:

    Mongomapper  3.290000   2.410000   5.700000 (  5.761945)

Down from **1730 usec/document** to **192 usec/document**, a gain of ~9x, making it competitive with Mongoid. At some point it becomes difficult to do an apples-to-apples comparison, as Mongoid uses the Moped driver to talk to MongoDB, while MongoMapper still uses the 10gen Mongo driver, so there is a divergence in terms of what each ODM is doing under the covers.

This is just the tip of the iceberg, but it's the core of the optimization pass. In the process of making these changes, I [converted the test suite to rspec](https://github.com/jnunemaker/mongomapper/commit/46992503b502f432309652bb55788673087327b4), [made embedded associations lazy-loaded](https://github.com/jnunemaker/mongomapper/commit/8e6cd50eac2e180978f556e269ded2255f23e31b), [added finer-grained control over document marshalling](https://github.com/jnunemaker/mongomapper/commit/520cc656faae99402a12a2d45cd38a454cb6dd03), added [ActiveRecord-style block syntax to document creation](https://github.com/jnunemaker/mongomapper/commit/98f264f47f01b7695cc580da90b0d4a3de7e55b6), [added key aliases](https://github.com/jnunemaker/mongomapper/commit/f001de06ca5487787862b8a94f898e5a88656a6a), and more.

All of this work and more has gone into getting MongoMapper back into the race in terms of speed, and I'm proud to say that the [0.13.0.beta1 release](http://rubygems.org/gems/mongo_mapper/versions/0.13.0.beta1) has been published and is looking great so far. If all goes well, then we'll be pushing 0.13.0 soon, which will be the last release in the 0.x series. Once that happens, we'll be merging in [Rails 4 compatibility](https://github.com/cheald/mongomapper/tree/rails4), making some [backwards-incompatible improvements to embedded associations](https://github.com/jnunemaker/mongomapper/pull/529), and more. Onward, to the future!