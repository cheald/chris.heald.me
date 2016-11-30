---
layout: post
title: Quick tip - use anonymous blocks!
categories: []
tags:
- blocks
- memory
- performance
- Rails
- Ruby
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '360463589'
---
In tracking down a memory leak in one of our Rails apps today, I ran across an <a href="http://blog.pluron.com/2008/02/rails-faster-as.html">interesting post</a> detailing the difference between anonymous and named blocks in Ruby, and the performance differences therein.

It's definitely worth a look, especially if you're running in a complex environment, where new closures will be large and unwieldy. It's very easy, too. Any time you use:

~~~ruby
def note(text, options = {}, &block)
  options[:class] = ((options[:class] || "") + " form-note").strip
  content_tag(:div, text, options, &block)
end
~~~

Instead, don't explicitly name the block parameter; just yield to it, and you prevent all the messiness of creating a new Proc object.

~~~ruby
def note(text, options = {})
  options[:class] = ((options[:class] || "") + " form-note").strip
  content_tag(:div, text, options) {|*block_args| yield(*block_args) if block_given? }
end
~~~

I don't have benchmarks just yet, but anecdotally it has definitely slowed instance memory consumption in my apps. It's worth taking a look at!
