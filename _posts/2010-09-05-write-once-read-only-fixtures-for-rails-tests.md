---
layout: post
title: Write-once read-only fixtures for Rails tests
categories:
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '334842893'
---
In the project I'm currently working on, I'm heavily using <a href="http://github.com/thoughtbot/factory_girl">factory_girl</a> to generate test data, rather than using the old Rails fixtures standby. However, I still have a set of read-only fixtures (which are used for testing read-only models against a legacy database). I'm using these in my tests, but since they are read only (like, seriously - the models are marked as by using `after_find` to call `readonly!`, ensuring that records will not be accidentally written), there's no need to wipe and re-insert them per-test.

It's not too hard to set up fixtures to be inserted once per test suite run --

In your test_helper.rb, above the `class ActiveSupport::TestCase` definition, add the following:

~~~ruby
Fixtures.reset_cache
fixtures_folder = File.join(RAILS_ROOT, 'test', 'fixtures')
fixtures = Dir[File.join(fixtures_folder, '*.yml')].map {|f| File.basename(f, '.yml') }
Fixtures.create_fixtures(fixtures_folder, fixtures)
Fixtures.reset_cache
~~~

Next, turn off transactional fixtures and comment out the fixtures macro:

~~~ruby
self.use_transactional_fixtures = false
# fixtures :all
~~~

That's all there is to it. Your fixtures will be inserted into your test database once when test_helper is included for the first time, and then not again for the rest of the test suite run. This should speed your tests up substantially.
