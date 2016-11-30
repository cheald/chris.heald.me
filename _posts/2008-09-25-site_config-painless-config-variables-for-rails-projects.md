---
layout: post
title: site_config - painless custom configuration for your Rails project
categories:
- Rails
- Ruby
tags:
- configuration
- plugin
- Rails
- Ruby
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '335200377'
---
[site_config](http://github.com/cheald/site_config/tree/master) is a little plugin that addresses a problem lots of people seem to need to solve in their Rails apps: per-environment configuration variables.

It's very simple, but makes configuration dead-easy. To install it:

    script/plugin install git://github.com/cheald/site_config.git

Once you have it installed, check out `config/site_config.yml` - there's your config file.

You'll notice that it has some dummy data in there to begin with. It's much like your `database.yml` file; just specify the environment, and under that, specify the key:value pairs you want to have available in your app. site_config has one little trick up its sleeve, though - the key "inherit" is special, and tells it to pull values from another environment. This helps you DRY up your configs, and makes it quite easy to maintain.

For example, if you had the following `site_config.yml`:

~~~yaml
development:
  page_title: "my development site"
  admin_user: chris

production:
  inherit: development
  page_title: "my production site"
~~~

You can then use those configured values in your site like so:

~~~erb
<title><%=config_option :page_title %></title>
Your friendly admin is <%=config_option :admin_user %>
~~~

site\_config will pull values defined for your current environment. If you don't have a value defined for a given environment, but do have an `inherit` defined, site\_config will then look to the inherited config to pull values from.

Additionally, if you want a value from a specific environment, `config_option` accepts a second parameter, which specifies the environment to pull from.

~~~ruby
config_option :page_title, :development
~~~

There's more at the [github page](http://github.com/cheald/site_config/tree/master). Check it out.
