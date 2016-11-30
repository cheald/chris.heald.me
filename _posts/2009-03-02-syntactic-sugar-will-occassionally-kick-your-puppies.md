---
layout: post
title: Syntactic sugar will occassionally kick your puppies.
categories:
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '335200599'
---
Ruby's awesome. It has sweet, concise syntax that makes for clean, readable code. One of these constructs is the trailing condition. In most languages where you might have to write something like:

~~~ruby
if foo then
	do_stuff
end
~~~

Ruby will let you clean that up with:

~~~ruby
do_stuff if foo
~~~

This works just nearly all the time, but I ran into an odd problem today, where the trailing conditions were producing behavior I didn't want.

~~~irb
>> foobar
NameError: undefined local variable or method `foobar' for #<Object:0x92bc998>
        from (irb#1):2
>> foobar = true unless defined?(foobar)
=> nil
>> foobar
=> nil
>> unless defined?(foobar); foobar = true; end
=> true
>> foobar
=> true

~~~

Wait, what? Using the trailing conditional changes the order in which Ruby parses the statement, resulting in something like the following operations:

1. Define `foobar` because it's referenced, set it to `nil`
1. Parse the `unless` conditional
1. If the condition is true, set `foobar` to `true`

The kicker here is that because `foobar`'s assignment is the first thing parsed, it's always initialized before you ever get to the `defined?` statement. So instead, we run the second piece of code:

~~~ruby
unless defined?(foobar); foobar = true; end
~~~

This runs something like the following:

1. Parse the `unless` condition.
1. Define `foobar `because it's referenced, set it to `nil`
1. If the condition is true, set `foobar `to `true`

Obviously this is the desired behavior. Several lessons here:


* Ruby initializes variables _when they are parsed_, not when the code path that contains them is run (in fact, it'll even initialize variables that are in unreachable code paths!)
* `if condition then do_stuff end` is not always the same as `do_stuff if condition`

It's a bit of an edge case, but it's an edge case that had me baffled. Hopefully this post saves you some frustration.
