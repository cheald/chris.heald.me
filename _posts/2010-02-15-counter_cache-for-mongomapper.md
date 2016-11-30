---
layout: post
title: counter_cache for MongoMapper
categories:
- MongoDB
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '336172016'
---
I've started playing with <a href="http://github.com/jnunemaker/mongomapper">MongoMapper</a>, and it's quite excellent, but it does suffer very much from being young. There are lots of pieces missing that veterans of ActiveRecord will take for granted. I've been working around or patching them, for the most part, but I felt that my solution to `:counter_cache` deserved a post.

In short, I didn't want to hack around with the MongoMapper associations code, so I just implemented my own little ride-along version.

~~~ruby
module SecretProject
  module CounterCache
    module ClassMethods
      def counter_cache(field)
        class_eval <<-EOF
          after_create "increment_counter_for_#{field}"
          after_destroy "decrement_counter_for_#{field}"
        EOF
      end
    end

    module InstanceMethods
      def method_missing(method, *args)
        if matches = method.to_s.match(/^(in|de)crement_counter_for_(.*)$/) then
          dir = matches[1] == "in" ? 1 : -1
          parent_association = matches[2]
          if parent = self.send(parent_association) then
            name = "#{self.class.to_s.tableize}_count"
            if parent.respond_to?(name)
              parent.collection.update({:_id => parent._id}, {"$inc" => {name => dir}})
            end
          end
        else
          super
        end
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end
~~~

Throw that into your lib directory, load it with an initializer, and then you can use it something like so:

~~~ruby
class Foo
  include MongoMapper::Document
  include SecretProject::CounterCache

  belongs_to :user
  counter_cache :user  # Will cause a foos_count field on the owning user to be maintained when a Foo is created or deleted.
end
~~~

This'll only increment a counter if you've defined one on your parent object, via `key :foos_count, Integer` or similar, just so that it doesn't go around updating every model you might associate it with.

Yay.
