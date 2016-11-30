---
layout: post
title: Fine tuning your garbage collector
categories:
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '334858600'
---
If you're familiar with Ruby at all, you know that it can be a little wacky when it comes to memory usage. Most of us have observed a Mongrel/Passenger instance that starts out small and then grows by leaps and bounds, eventually settling on some uncomfortably high number. We're going to fix that with <a href="http://www.rubyenterpriseedition.com/">Ruby Enterprise Edition</a> and <a href="http://github.com/cheald/scrap/tree/master">Scrap</a>.

The Ruby garbage collector's behavior is controlled by a number of constants. In the MRI, these are compiled into Ruby itself, and don't change. However, if you're using REE you can override them with environment variables on startup. It's terribly handy.

### First, the boring documentation
All the juicy information is available <a href="http://www.rubyenterpriseedition.com/documentation.html#_garbage_collector_performance_tuning">in the documentation</a>, but I'm going to just go over the key points real quick.

* `RUBY_HEAP_MIN_SLOTS`: This is the number of "heap slots" that each Ruby instance starts up with. One heap slot can hold one Ruby object. By default, this is 10,000. By controlling this value, we can get our apps to stabilize very quickly. More on this later.
* `RUBY_HEAP_SLOTS_INCREMENT`: Once Ruby has allocated `RUBY_HEAP_MIN_SLOTS` objects on its first heap, it will have to allocate a second heap to make room for more. This variable controls the size of this second heap, and sets the baseline for future heaps, as well.
* `RUBY_HEAP_SLOTS_GROWTH_FACTOR`: For heaps #3 and onward, Ruby uses `RUBY_HEAP_SLOTS_INCREMENT` and this value to determine the size to allocate for the new heap. By default, this is 1.8, meaning that your third heap will end up with 10,000 * 1.8 = 18,000 slots in it.
* `RUBY_HEAP_FREE_MIN`: After each garbage collection run, if the number of free slots is less than `RUBY_HEAP_FREE_MIN`, a new heap will be allocated. The default is 4096.

So, let's look at this practically. Presume that we have a Rails process that is going to require 50,000 Ruby objects before it's fully initialized. The allocation process, when at defaults, will look something like this:

* Allocate 10,000 slots (10,000 total available)
* Allocate 10,000 slots (20,000 total available)
* Allocate 18,000 slots (38,000 total available)
* Allocate 68,400 slots (106,400 total available)

So, we end up with about 53% more slots than we actually needed, and it took us four heap allocations to even boot the process. Surely we can do better.

### Enter Scrap.

<a href="http://github.com/cheald/scrap/tree/master">Scrap</a> is a little <a href="http://weblog.rubyonrails.org/2008/12/17/introducing-rails-metal">Metal</a> handler I wrote for tracking memory usage and garbage statistics over an instance's lifetime. Installing it is trivial - just drop it into your vendor directory, restart your app, and navigate to `http://yoururl.com/stats/scrap`.

With this in hand, we can peek our memory usage and see what we can see.

There are some stats at the top, but for our purposes, we're interested in the per-request garbage statistics. The newest request is near the top of the file, and the oldest request is at the bottom of the file. The last 50 requests are tracked. Each request looks something like this:

    [71.92 MB] GET /apps/176568-WordPress

    Number of objects    : 817571 (658305 AST nodes, 80.52%)
    Heap slot size       : 20
    GC cycles so far     : 503
    Number of heaps      : 7
    Total size of objects: 15968.18 KB
    Total size of heaps  : 18036.81 KB (2068.63 KB = 11.47% unused)
    Leading free slots   : 27104 (529.38 KB = 2.93%)
    Trailing free slots  : 1 (0.02 KB = 0.00%)
    Number of contiguous groups of 16 slots: 2829 (4.90%)
    Number of terminal objects: 4307 (0.47%)

Key points here for the time being are _Number of objects_ and _Number of heaps_. When we look at the number of objects - in this case, 817,000, it's obvious that we're going to have to allocate a number of heaps to handle all those objects. Rails' boot-up cost is fairly significant, and the default Ruby settings just really don't cut it here. As you can see, we've allocated 7 heaps, and we're using 15.9 of 18.0 MB allocated to the heap. Once a heap is allocated, it's never de-allocated, so we're perma-stuck at 18 MB of heap usage. Note that this isn't the size of all the data in the program - just the space allocated for objects. A string that contains 100MB of data will only consume 20 bytes (that's the "heap slot size - the amount of memory each object on the heap consumes") on the heap.

However, what if we could just allocate the whole startup cost in the initial heap, and save ourselves the problems of having to reallocate so often?

We note that we have 891k slots allocated, so we can guesstimate at a number to set our initial allocation to. In my production app, I set mine to 1,250,000 - I was observing peaks around the 1,100,000 mark, and just increased it by 10% and rounded up.

So, my first custom environment variable is

`RUBY_HEAP_MIN_SLOTS=1250000`

And it results in something like this on the app's first boot:

    [137.99 MB] GET /movies/7505-Star-Wars-Episode-V-The-Empire-Strikes-Back
    Number of objects    : 933037 (664785 AST nodes, 71.25%)
    Heap slot size       : 20
    GC cycles so far     : 12
    Number of heaps      : 1
    Total size of objects: 18223.38 KB
    Total size of heaps  : 24414.08 KB (6190.70 KB = 25.36% unused)
    Leading free slots   : 316963 (6190.68 KB = 25.36%)
    Trailing free slots  : 0 (0.00 KB = 0.00%)
    Number of contiguous groups of 16 slots: 19810 (25.36%)
    Number of terminal objects: 25941 (2.08%)

Yowza, a full 25% of my heap is unused after boot. But...well, that's okay. We've only allocated 1 heap, and later on, my object allocation grows to around 1,100,000. This is still 15k under the heap size, and I've set `RUBY_HEAP_FREE_MIN=12500` (1% of the initial size), so if I have less than 12,500 heap objects free after a GC cycle, a new heap will be allocated. Stabilizing there means that I end up with 1 heap for the lifetime of my app, and I end up sitting just under the threshold that'd cause a new heap to be born. If I have a leak, or a super heavy action or something, though, that might kick me over my limit and require a new heap. So, we come to...

`RUBY_HEAP_SLOTS_INCREMENT=100000`

This value says "Hey, if you have to allocate a second heap, start with this many slots". If we go over our limit of 1.25 million slots, we'll allocate a second heap that's about 8% the size of the original. That seems awfully small, but consider that we're hoping to never get to that heap.

Should we end up using that entire second heap, then we have to worry about our third setting, `RUBY_HEAP_SLOTS_GROWTH_FACTOR=1`. This says "Each new heap should be 1.0 as large as the previous heap." In this case, it means I'll keep allocating 100k-slot heaps until the cows come home. In an untuned environment, this could be bad - we would either end up having to do a <em>ton</em> of allocations to get to our target, or we would overallocate very badly. However, because we know our app's memory requirements, and know about where we want it to end up, a relatively small, linear growth factor is just what the doctor ordered here.

### Okay, now what?
So, we have a collection of settings with which to run our app. Great! Now, how do we use it?

Fortunately, it's easy.

    pushd `which ruby | xargs dirname`
    sudo vim ruby-with-env

We're going to create a little bash script with the following:

~~~bash
#!/bin/bash
export RUBY_HEAP_MIN_SLOTS=1250000
export RUBY_HEAP_SLOTS_INCREMENT=100000
export RUBY_HEAP_SLOTS_GROWTH_FACTOR=1
export RUBY_GC_MALLOC_LIMIT=30000000
export RUBY_HEAP_FREE_MIN=12500
exec "/opt/ree/bin/ruby" "$@"
~~~

Note that last line - the path will have to match the path to your Ruby executable, which fortunately, should be in the directory that you're in.

Save it, don't forget to `chmod a+x ruby-with-env`, and then edit your Apache or nginx configuration.

Under nginx, you'll have a line like this:

    passenger_ruby /opt/ruby-enterprise-1.8.6-20090610/bin/ruby;

Just change it to use your new wrapper script, like so:

    passenger_ruby /opt/ruby-enterprise-1.8.6-20090610/bin/ruby-with-env;

The process is similarly easy for Apache - the line you need is something like:

    PassengerRuby /opt/ruby-enterprise-1.8.6-20090610/bin/ruby

It might be in either your `httpd.conf` or `conf.d/passenger.conf`.

Once you're all edited up, restart your webserver, and congratulations, you've got a fine-tuned garbage collector humming along with your app.

### Taking out the garbage

"But Chris!", you say, "There's a variable in there that you didn't talk about! What gives?" You are indeed correct, astute reader. We've thus far avoided the `RUBY_GC_MALLOC_LIMIT` variable. This is a handle little setting that lets you tell Ruby how often to clean up after itself. Ruby is written in C, and C uses `malloc` to allocate memory. Ruby just keeps a little counter each time it allocates an object with malloc, and it runs its garbage collector after so many malloc calls have been made. I haven't found a great way to tune this one yet, except via experimentation, but here's what to know about it:

1. The lower this value is, the more often your garbage collector runs. Garbage collection is slow. Garbage collection is painfully slow. If a user is waiting on garbage collection, they are going to become impatient. You want as few users waiting on garbage collection as possible.
1. The higher this value is, the more memory Ruby will allocate before it tries to clean up after itself. If this value is too high, you'll have dead objects hanging around eating up heap space, and possibly causing Ruby to crap itself and allocate a new heap. This is bad.
1. To tune this value, you want to find the happy medium, wherein you stabilize under your initial heap allocation value, but with as few garbage collection passes as possible. Read up on <a href="http://blog.evanweaver.com/articles/2009/04/09/ruby-gc-tuning/">Evan Weaver's blog</a> for some more in-depth analysis of what garbage collection frequency tuning can do to your app's performance.
1. If you have excess memory and want a faster app, err on the side of this being too high. If you are on a tight memory budget, and would prefer slower actions in exchange for not blowing your heap and allocating a whole new one, err on the side of this being too low.
1. Recommended values for this are all over the board. Evan recommends a setting of 50 million. I'm using a setting of 30 million. The Ruby default is 8 million. You'll have to play around and find what works best for you. Just pay attention to how many requests there are in between that "GC cycles so far" number incrementing in Scrap, and you'll be able to measure approximately how often you're entering a GC cycle.

Good luck with it, and have fun!
