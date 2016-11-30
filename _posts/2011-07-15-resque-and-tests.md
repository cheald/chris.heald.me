---
layout: post
title: Resque and Tests
categories:
- Rails
- Ruby
tags:
- redis
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '359732855'
---
<a href="https://github.com/defunkt/resque">Resque</a> is a bucket of awesome slathered in a delicious candy coating. It makes background job work really, *really* easy. I recently switched to it, and found that in the process of testing it, I was generating an awful lot of extra unfulfilled jobs in my queue, when the job was a side-effect of some other test (rather than what was being tested explicitly).

I couldn't find a quick and easy answer to this with some Googling, but it turns out that the answer is fortunately rather simple.

In your `test_helper.rb`:

~~~ruby
 def setup
    Resque.redis.select 1
  end

  def teardown
    Resque.redis.keys("queue:*").each {|key| Resque.redis.del key }
  end
~~~

That's all there is to it. The `setup` causes Resque to write to database #1 (#0 is default, and is what your development environment is likely using), and the `teardown` just deletes all your queues (which are really just lists of jobs to run). Test all you want and you won't have to worry about tens of thousands of jobs junking up your redis DB.
