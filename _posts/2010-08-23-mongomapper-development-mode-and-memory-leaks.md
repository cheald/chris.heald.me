---
layout: post
title: MongoMapper, Development Mode, and Memory Leaks
categories:
- MongoDB
- Performance
- Ruby
tags:
- debugging
- fixes
- gdb
- memory leak
- mongomapper
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '335101487'
---
If you've worked with MongoMapper for a while, you've probably noticed that in complex apps, there are horrific memory leaks in development that magically disappear in production mode. While this is all well and good, and it's rather handy that things Just Work in production, don't you wish you didn't have to restart your app server every 15 requests in development?

I set out to track down the cause tonight, and have both fixed the problem and gotten some handy experience debugging Rails apps with gdb.

<h2>The Solution</h2>

First off, if you just want the fix, here it is. You probably have a middleware to clear your identity maps already. We're just going to modify that. In my case, it's `lib/mongo_mapper/per_request_identity_map_clear.rb`.

~~~ruby
module MongoMapper
  class PerRequestMapClear
    def initialize(app)
      @app = app
    end

    def call(env)
      if Rails.configuration.cache_classes
        MongoMapper::Plugins::IdentityMap.clear
      else
        MongoMapper::Document.descendants.each do |m|
          m.descendants.clear if m.respond_to? :descendants
        end
        MongoMapper::Document.descendants.clear
        MongoMapper::EmbeddedDocument.descendants.clear
        MongoMapper::Plugins::IdentityMap.clear
        MongoMapper::Plugins::IdentityMap.models.clear
      end
      @app.call(env)
    end
  end
end
~~~

In particular, these two lines:

~~~ruby
MongoMapper::Document.descendants.clear
MongoMapper::Plugins::IdentityMap.models.clear
~~~

Make sure you get that into your middleware stack and all your MongoMapper memory leaking issues will magically disappear.

<h2>The Problem</h2>

You see, MongoMapper is doing some <em>dag-nasty evil stuff</em> with class references. Namely, it's holding onto them in class variables that don't get reloaded per-request in Rails. Simply:

1. Rails loads your `User` model. This loads up a ton of `Validation`s, `MongoMapper::Key`s, procs, and whatever else you have in your model definition. It's not really light. That's okay because we load it only once in production.
1. This is a `MongoMapper::Document`, which causes User (the class reference) to be inserted into the `MongoMapper::Document.descendants` class attribute, which happens to be a `Set` object.
1. Next time you refresh a page, Rails re-loads your `User` model. This creates a <em>new and separate `User` class</em>. It does not replace the previous `User` class reference. It is not equal to your previous `User` class reference. They are, as far as Ruby cares, separate objects.
1. MongoMapper happily sticks that class reference into its `descendants` class attribute. You now have two separate copies of User. Since MongoMapper is holding onto a reference to your old User class, Ruby can never garbage collect it. The old User class and all of its huge cascading chain of referenced objects are now "leaked".
1. Your memory usage is increasing by 4mb per request now.

I had app instances reaching nearly 1GB of RAM usage after light testing. I finally noticed it when my development machine kicked into swap and actions that took 80ms to run were taking 8000ms to run. Hm. That might be a problem!

<h2>Debugging leaks with GDB</h2>

GDB is an amazing tool. With a few macros, you can make hacking around in a live Ruby instance pretty painless. Crack open your `/root/.gdbinit` file and add a few macros:

~~~bash
define eval
  call(rb_p(rb_eval_string_protect($arg0,(int*)0)))
end

define redirect_stdout
  call rb_eval_string("$_old_stdout, $stdout = $stdout, File.open('/tmp/ruby-debug.' + Process.pid.to_s, 'a'); $stdout.sync = true")
end
~~~

Now, we're going to attach to your running Ruby process. This needs to be done as root.

~~~bash
[root@polaris ~]# gdb
(gdb) attach 12019
(gdb) redirect_stdout
(gdb) eval "ObjectSpace.each_object {|o| puts \"#{o.class.name}, #{o.inspect} -- #{o.object_id}\" unless o.is_a?(String) }; puts '----'"
~~~

This will effectively dump all non-String objects in the attached Ruby process to `tmp/ruby-debug.12019`. This takes a little bit, but it lets you come up with some handy data for parsing later.

To get data we can compare, we'll need to dump the environment for multiple requests:

~~~bash
[root@polaris ~]# gdb
(gdb) attach 12019
(gdb) redirect_stdout
(gdb) eval "GC.start"
(gdb) eval "ObjectSpace.each_object {|o| puts \"#{o.class.name}, #{o.inspect} -- #{o.object_id}\" unless o.is_a?(String) }; puts '----'"
(gdb) detach

(run some requests)

(gdb) attach 12019
(gdb) redirect_stdout
(gdb) eval "GC.start"
(gdb) eval "ObjectSpace.each_object {|o| puts \"#{o.class.name}, #{o.inspect} -- #{o.object_id}\" unless o.is_a?(String) }; puts '----'"
(gdb) detach
~~~

At this point, you'll have two ObjectSpace dumps in your temp file. For my purposes, I hacked up a quick little script to parse those dumps, and to output all objects that were not present in both dumps. Since I'm invoking GC.start, in theory, this should help me find my leaked objects.

~~~ruby
runs = [[]]
open(ARGV[0]).each do |line|
  if line == "----\n" then
    runs << []
  elsif line.match "--" then
    runs.last << line.strip
  end
end

diff = []
runs.each do |run|
  diff = (diff - run) | (run - diff)
end
diff.sort.map {|d| puts d }~~~

Not very pretty, but it does the job. Just a quick invocation to `ruby find_leaked.rb /tmp/ruby-debug.12019 > leaked` (well, not that quick, it took a minute to run) and I effectively had an ObjectSpace diff I could pore through.

There's a lot of stuff in there. In particular, you're going to notice that you have a LOT of Array, Hash, and MatchData objects (perhaps potential optimization points for future Rails releases?). While we may be interested in those, try to cull out the things that obviously aren't a problem just for readability's sake.

I pored through the diff looking for things related to MongoMapper or my models. After not too long, I came across these lines:

~~~ruby
Set, #<Set: {Achievement, EmbeddedComment, Achievement, EmbeddedComment, EmbeddedComment, Achievement, Achievement, EmbeddedComment, EmbeddedComment, Achievement, EmbeddedComment, EmbeddedComment, Achievement, Achievement, Achievement, EmbeddedComment, EmbeddedComment, Achievement}> -- 92034680
Set, #<Set: {Achievement, EmbeddedComment, Achievement, EmbeddedComment, EmbeddedComment, Achievement, Achievement, EmbeddedComment, EmbeddedComment, Achievement, EmbeddedComment, EmbeddedComment, Achievement, Achievement, EmbeddedComment, Achievement, Achievement, EmbeddedComment, EmbeddedComment, Achievement}> -- 92034680
~~~

Whoa there. What? Why do I have Sets with multiple references to `Achievement` and `EmbeddedComment`? That doesn't smell right. I suspect the problem lies in MongoMapper, so let's grep the MongoMapper codebase for Set.

~~~bash
[chris@polaris lib]$ grep Set * -R
mongo_mapper/plugins/identity_map.rb:        @models ||= Set.new
mongo_mapper/plugins/modifiers.rb:          modifier_update('$addToSet', args)
mongo_mapper/plugins/protected.rb:          self.write_inheritable_attribute(:attr_protected, Set.new(attrs) + (protected_attributes || []))
mongo_mapper/plugins/accessible.rb:          self.write_inheritable_attribute(:attr_accessible, Set.new(attrs) + (accessible_attributes || []))
mongo_mapper/support/descendant_appends.rb:        @descendants ||= Set.new
mongo_mapper/connection.rb:      raise 'Set config before connecting. MongoMapper.config = {...}' unless defined?(@@config)
mongo_mapper/connection.rb:      raise 'Set config before connecting. MongoMapper.config = {...}' if config.blank?
mongo_mapper/extensions/set.rb:    module Set
mongo_mapper/extensions/set.rb:class Set
mongo_mapper/extensions/set.rb:  extend MongoMapper::Extensions::Set
~~~

Great, we have a hit list to look through. IdentityMap is worth looking at; a new set is created there, and its naming indicates that it's for holding models, probably model references (it is). `mongo_mapper/support/descendant_appends.rb` is much the same deal. We can ignore `mongo_mapper/plugins/accessible.rb` since we can guess that the `attrs` being passed are symbols, rather than those class references we saw in the ObjectSpace diff.

Let's crack open `descendant_appends.rb`

~~~ruby
module MongoMapper
  module Support
    module DescendantAppends
      def included(model)
        extra_extensions.each { |extension| model.extend(extension) }
        extra_inclusions.each { |inclusion| model.send(:include, inclusion) }
        descendants << model
      end

      # @api public
      def descendants
        @descendants ||= Set.new
      end
~~~

Oh dear. And there it is. Every time `MongoMapper::Support::DescendantAppends` is included in a model (which is via `MongoMapper::Document` and `MongoMapper:EmbeddedDocument`), <em>a reference to the including class</em> is stored in a <em>class variable</em>.

Since we know that Rails reloads models per-request in development mode, and we know that each copy of a model's class is not considered equivalent to the other copies of that class, it's easy to see what happens here: We end up with sets like in our object dump, with however many orphaned old copies of our models, and all their various and sundry associated models.

And so, we arrive at our solution. By clearing the <em>descendants</em> set on every request where we are reloading our models, we ensure that there are not references to old copies of models left hanging around leaking memory.

My development instances are now running solid at 68mb apiece, rather than 1gb apiece. As you can imagine, the difference in response speed (and thus, productivity) is substantial.

Hope this helps. Have fun with gdb - it's an obscenely powerful tool, and used properly, can give you a purely nutty amount of information which can be invaluable in tracking down memory leaks and related problems.
