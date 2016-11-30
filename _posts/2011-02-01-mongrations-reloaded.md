---
layout: post
title: Mongrations reloaded
categories:
- MongoDB
- Rails
tags:
- gem
- library
- mongrations
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _wp_old_slug: ''
  dsq_thread_id: '334938472'
---
Users of <a href="https://github.com/jnunemaker/mongomapper">MongoMapper</a> may be familiar with mongrations, a Rails plugin to provide you with ActiveRecord-style migration tools for MongoDB. You don't need them for schema changes, obviously, since MongoDB is schemaless, and you can define any changes you need to in your model. However, there are times that deploying a changeset will require some data change, or some maintenance stuff to be run. For that, mongrations is super helpful. Or was.

It's been broken for some time now, and not really in much of a state to be used by anyone, but I needed it, so I fixed it up. You can get my source <a href="https://github.com/cheald/mongrations">on github</a>, but I've done one easier and made it a gem. Major changes are:

* Bad assumptions fixed. Actually works now.
* Reorganized the whole thing and repackaged it as a gem. Doesn't work as a Rails plugin anymore, but that's okay. Just add it to to your environment or Gemfile and you're good to go.
* Added tests!
* Fixed documentation, and normalized rake tasks names.

To get it, you can just `gem install mongrations` and you're off to the races.

This is primarily going to be useful for MongoMapper people, who are likely still on Rails 2.3.x. If you're using mongoid, check out <a href="https://github.com/adacosta/mongoid_rails_migrations">mongoid\_rails\_migrations</a> instead.
