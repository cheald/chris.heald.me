---
layout: post
title: Tarot for easier Rails configurations
categories:
- Rails
- Ruby
tags:
- tarot
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '344746957'
---
Once upon a time, I wrote a <a href="http://www.coffeepowered.net/2008/09/25/site_config-painless-config-variables-for-rails-projects/">quick-and-dirty Rails plugin for site configuration</a>. Since then, I've continued to use variants on this pattern, and it's evolved to the point that it deserved a revisit.

After continually slimming down the code, I realized that even though it's tiny, it's <em>danged useful</em> to be able to just drop this into a Rails app and go. Thus, I'd like to present <a href="https://github.com/cheald/tarot">Tarot</a>, my Rails configuration solution.

Tarot's current form is heavily inspired by the Rails I18n usage, and is very quick and easy to use in your app. The generator installs a sample yaml file at config/tarot.yml, as well as an initializer to bootstrap your configuration and provide a handy helper method for quick access to those config values.

Assuming you have a config file like so:

~~~yaml
---
base: &base
  foo: bar
  nested:
    tree: value
  array:
    - value 1
    - value 2

development: &development
  <<: *base

test: &test
  <<: *base

production: &production
  <<: *base
  foo: baz
~~~

You'll notice that all the environments inherit from your base environment; this gives you an easy way to define common settings once, then override them per environment. Handy!

You could can access values by key, or by dot-delimited path:

~~~ruby
config('foo') => 'bar'
config('nested.tree') => value
~~~

Default values are similarly easy.

~~~ruby
config('foo.missing', 42) => 42
~~~

Finally, while Tarot will read your current application environment's config, if you want to reach into another environment, that's likewise easy:

~~~ruby
config('foo', nil, 'production') => 'baz'
~~~

As of 0.1.2, Tarot also supports method_missing invocation:

~~~ruby
Config = Tarot::Config.new('settings.yml', Rails.env)
Config.foo.bar.baz => "bin"
~~~

It also supports default values:

~~~ruby
# Assuming foo has no subkey bar
Config.foo.bar("default") => "default"
~~~

But it'll fail if you try to invoke method_missing on a non-leaf node

~~~ruby
# Assuming that there is no `blaze` tree
Config.blaze.blarg => NameError
~~~

That's about all there is to it -- config isn't (or shouldn't be) a hard problem, so there's not a whole lot to it, but it should get you up and running with easily-configured Rails apps in seconds.
