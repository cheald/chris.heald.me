---
layout: post
title: 'Powerful, easy, DRY, multi-format REST APIs: Part 2'
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '335200574'
---
Back in September, I wrote about <a href="http://www.coffeepowered.net/2008/09/27/powerful-easy-dry-multi-format-rest-apis/">making your REST APIs more flexible and easier to maintain</a>. I've been working with this code with great success for the past few months, and have improved and tweaked it. It's changed enough that it's time for another blog post about it.

First off, the `render` method signature has changed. This is for full Rails compatiblity, including Rails 2.3. It'll work as you'd expect without any unpleasant surprises. Secondly, there are some other optional render targets, designed for leveraging existing `#to_xml` handlers where you already like them.

It's easy. Throw this bad boy into your `application_controller.rb`, or mix it in via a module.

Quick **IMPORTANT** note: If you aren't already, use `libxml` and `faster_xml_simple` as outlined in the original post. If you aren't, you're using REXML, which is a mindblowingly bad use of resources and a very quick way to Painsville, population you.

~~~ruby
def render(opts = nil, extra_options = {}, &block)
	if opts then
		if opts[:to_yaml] or opts[:as_yaml] then
			headers["Content-Type"] = "text/plain;"
			text = nil
			if opts[:as_yaml] then
				text = Hash.from_xml(opts[:as_yaml]).to_yaml
			else
				text = Hash.from_xml(render_to_string(:template => opts[:to_yaml], :layout => false)).to_yaml
			end
			super :text => text, :layout => false
		elsif opts[:to_json] or opts[:as_json] then
			content = nil
			if opts[:to_json] then
				content = Hash.from_xml(render_to_string(:template => opts[:to_json], :layout => false)).to_json
			elsif opts[:as_json] then
				content = Hash.from_xml(opts[:as_json]).to_json
			end
			cbparam = params[:callback] || params[:jsonp]
			content = "#{cbparam}(#{content})" unless cbparam.blank?
			super :json => content, :layout => false
		else
			super(opts, extra_options, &block)
		end
	else
		super(opts, extra_options, &block)
	end
end
~~~

This provides the following render targets:

~~~ruby
render :to_yaml => "some.xml.builder"
render :to_json => "some.xml.builder"
render :as_yaml => record.errors.to_xml
render :as_json => record.errors.to_xml
~~~

As a bonus, it also supports jsonp callbacks, if the client requests them via a "jsonp" (via the spec) or "callback" (via jquery) parameter. You don't have to worry about it - the client just asks for it with their JSON and it gets all wrapped up nice and neat with a little bow. Totally easy.

The beauty, as outlined in the previous post, is that this lets you consolidate your formatted views, and ensure that they're always in synch. Check out how easy this is:

~~~ruby
def create
	@record = Record.new(params[:record])
	if @record.save then
		respond_to do |wants|
			wants.html
			wants.xml
			wants.json { render :to_json => "create.xml.builder" }
			wants.yaml { render :to_yaml => "create.xml.builder" }
		end
	else
		respond_to do |wants|
			wants.html { render :action => :new }
			wants.xml  { render :xml => @record.errors.to_xml }
			wants.json { render :as_json => @record.errors.to_xml }
			wants.yaml { render :as_yaml => @record.errors.to_xml }
		end
	end
end
~~~

This gives you both informative success and failure responses with fully controlled record responses. Let's say that when you create a new record via the API, you don't want to return the entire record - just the ID, title, and associated photo. Your associated builder looks like this:

~~~ruby
xml.record(:id => @record.id, :title => @record.id) do
	xml.photo(:url => @record.photo.url)
end
~~~

Not too bad. It's only the data you want to expose, and you have full control over data from associations. You can do anything you want with this builder - loop over associations, render partials, you name it. You can get as fancy as your needs demand.

So, what's it do? Let's see. Posting to /records.$format gets you a response in the format you want, or errors in the format you want.

Want XML? Sure, no problem.

~~~xml
<?xml version="1.0" encoding="UTF-8"?>
<record id="1234" title="My record">
	<photo url="http://myurl.com/photo.jpg" />
</record>
~~~

Problems saving it? No problem. You get back nice clean XML.

~~~xml
<?xml version="1.0" encoding="UTF-8"?>
<errors>
  <error>Title can't be blank</error>
</errors>
~~~

What's that? You wanted it in JSON instead? Sure.

~~~json
{"errors":{"error":"Title can't be blank"}}
~~~

Or you specified a jsonp callback in your initial call?

~~~js
jsonp_1251236212312({"errors":{"error":"Title can't be blank"}});
~~~

Need YAML instead?

~~~yaml
---
errors:
  error:
  - Title can't be blank
~~~

Totally, completely flexible. You control what gets sent to the user, but you don't have to maintain multiple views for what is essentially the same content anyhow. No more huge 20-line respond-to blocks. No more brittle `#to_xml`, `#to_json`, and `#to_yaml` overrides in your models. No more fretting about getting your data into your users' hands in a robust, maintainable, and agile fashion. Stop worrying about keeping your `create.xml.builder, create.json.erb, create.yaml.erb, errors.xml.builder, errors.json.erb`, and `errors.yaml.erb` files in synch.

You just write your code, and write two views: Your web browser view, and your data API view. Why repeat yourself? Let Rails take care of the heavy lifting, leaving you to make the Awesome Stuff(TM) happen. You get the ability to stop worrying about brittle to_xml methods and maintaining four separate views for every tiny change, and your users get the ability to get their data exactly how they want it. Everybody wins.
