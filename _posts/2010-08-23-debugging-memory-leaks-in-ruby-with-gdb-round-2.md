---
layout: post
title: Debugging memory leaks in Ruby with GDB, round 2.
categories:
- MongoDB
- Performance
- Ruby
tags:
- debugging
- gdb
status: publish
type: post
published: true
meta:
  _syntaxhighlighter_encoded: '1'
  _edit_last: '2'
  _wp_old_slug: ''
  dsq_thread_id: '335048869'
---
In <a href="http://www.coffeepowered.net/2010/08/23/mongomapper-development-mode-and-memory-leaks/">part 1</a>, I described how I located leaky `Set`s in MongoMapper by diffing the Ruby ObjectSpace with GDB. Today, I'm going to show you how to solve the problems that those sorts of diffs can reveal. In today's example, we're tracking leaky sets. In particular, a set is holding onto class references. We are going to:

<ol>
<li>Set up object creation tracking on the Set class</li>
<li>Find the leaky instance of our set using GDB</li>
<li>Locate what code created that Set instance</li>
</ol>

<!--more-->
First things first. Check out Sean Bradly's <a href="http://drunkhobo.com/~sean/gctrack.rb.html">GCTrack</a> module. I'm using a modified version of it to include object IDs in the tracker struct, so that we can perform reverse-lookups on an instance.

~~~ruby
# Sean Bradly (rhythmx at gmail) - 2010
# Modified by Chris Heald (cheald@gmail.com) - August 2010
module GCTrack
  # Class to track an object's lifecycle and where it was created
  class Tracepoint < Struct.new(:num, :call, :insp, :id)
    include Comparable
    # make it so the obj.num works as a simple key
    def <=>(obj)
      if obj.class <= self.class
        self.num <=> obj.num
      else
        self.num <=> obj
      end
    end
  end

  def self.included(klass)

    # Hook initialize to track this object
    klass.class_eval do
      alias_method :old_init, :initialize

      def initialize(*args)
        # Call original init
        old_init(*args)
        # trace creation and setup finalizer callback
        final_proc = self.class.gct_setup_finalizer(self, caller, inspect)
        # define the finalizer
        ObjectSpace.define_finalizer(self, final_proc)
      end
    end

    # Add some metaclass foo to track all the objects.
    # You cant track in an instance w/o creating circular
    # references and breaking Ruby's GC

    (
    class << klass;
      self;
    end).class_eval do
      def gct_setup_finalizer(obj, caller, insp)
        # create/log a tracepoint for this object
        num = gct_objnum
        tpoint = Tracepoint.new(num, caller, insp, obj.object_id)
        gct_add(tpoint)
        # call option init cb
        if self.respond_to?(:created)
          self.send(:created, tpoint)
        end
        obj = nil # don't let the proc track a ref to 'obj'
        # this callback happens at GC time
        final_proc = Proc.new do
          gct_del(tpoint)
          # call optional final cb
          if self.respond_to?(:deleted)
            self.send(:deleted, tpoint)
          end
        end
      end

      def gct_objnum
        @num ||= -1
        @num  +=  1
      end

      def gct_addlog
        @addlog ||= []
      end

      def gct_dellog
        @dellog ||= []
      end

      def gct_add(num)
        gct_addlog << num
      end

      def gct_del(num)
        gct_dellog << num
      end

      def gct_active
        gct_addlog - gct_dellog
      end

      def gct_origin(id)
        x = gct_addlog.select {|g| g.id == id }.first
        x.nil? ? nil : x.call.join("\n")
      end

      def gct_orphan_report
        # Get the leaked objects
        rpt     = ""
        leaked  = gct_active
        callers = leaked.map { |o| o.call }.sort.uniq
        # Iterate over source lines that have leaked objs
        callers.each do |calla|
          leaked_here = leaked.find_all { |o| o.call == calla }
          rpt << "==== #{leaked_here.size} leaked objects from:\n\n"
          calla.each { |l| rpt << "    #{l}\n" }
          rpt << "\n"
          rpt << "    == object data:\n\n"

          leaked_here.each do |o|
            rpt << "    num: #{o.num}, inspect: #{o.insp}\n"
          end
          rpt << "\n"
        end
        rpt
      end

    end
  end
end
~~~

Additionally, you'll want to patch the object you're interested in tracking.

~~~ruby
class Set
  include GCTrack
end
~~~

You'll want to include both of those at the top of your config.rb, before your initializer block. If you're tracking an object defined in your Rails app, just include GCTrack in the object definition, rather than in a monkeypatch.

Next, you need to be sure that you have your GDB macros set up properly. /root/.gdbinit should have the following:

~~~bash
define eval
  call(rb_p(rb_eval_string_protect($arg0,(int*)0)))
end

define redirect_stdout
  call rb_eval_string("$_old_stdout, $stdout = $stdout, File.open('/tmp/ruby-debug.' + Process.pid.to_s, 'a'); $stdout.sync = true")
end
~~~

(re)start your application, hit the leaky action a few times, and find its PID using `ps ax` or `top`. Once you have that, attach to the process with gdb, redirect your process's stdout to the tmp file with `redirect_stdout` and dump all `Set`s in your object space.

~~~bash
(gdb) attach 12345
(gdb) redirect_stdout
$8 = 2
(gdb) eval "GC.start"
(gdb) eval "ObjectSpace.each_object {|o| puts \"#{o.class.name}, #{o.inspect} -- #{o.object_id}\" if o.is_a?(Set) }; puts '----'"
~~~

Now that we have that, let's look at the tmp file, and locate the leaked set instance.

~~~ruby
Set, #<Set: {Achievement, Achievement, EmbeddedComment, Achievement, EmbeddedComment, EmbeddedComment}> -- 78376680
~~~

There, at the end, is our object ID. Now back over to gdb.

~~~bash
(gdb) eval "puts Set.gct_addlog.select {|g| g.id == 78376680}.first.call.join(\"\n\")"
~~~

Your tmp file should now have a stack trace for that object's allocation now. Track it down and beat it into submission.

    /opt/ruby-enterprise-1.8.7-2010.02/lib/ruby/gems/1.8/gems/mongo_mapper-0.8.3/lib/mongo_mapper/support/descendant_appends.rb:15:in `new'

You can do this for just about any object you'd like. Just mix in your GCTrack and easily find where in code a particular instance of an object was created. Just like that, debugging memory leaks goes from hunting guppies in the Atlantic to shooting fish in a barrel.

Have fun!
