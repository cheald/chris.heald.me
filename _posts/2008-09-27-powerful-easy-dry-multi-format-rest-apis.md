---
layout: post
title: Powerful, easy, DRY, multi-format REST APIs
categories:
- Rails
- Ruby
tags:
- api
- json
- jsonp
- Rails
- rest
- xml
- yaml
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '335200398'
---
Rails' baked-in REST support is great. Build your app right, and you can expose a programmatic interface to your users for free.

That said, many times providing views in non-HTML formats tends to be bulky and unwieldy. You end up with either very brittle representations of your data, or extremely bulky respond_to blocks in your controllers.

Fortunately, there's a better way! We're going to provide two new render targets, `:to_yaml` and `:to_json` which will let us write a single XML builder view, and then provide that view in XML, YAML, and JSON formats according to the consuming developer's preferences.

In `application.rb` you'll want to override the render method.

~~~ruby
def render(opts = {}, &block)
  if opts[:to_yaml] then
    headers["Content-Type"] = "text/plain;"
    xml = render_to_string(:template => opts[:to_yaml], :layout => false)
    render :text => Hash.from_xml(xml).to_yaml, :layout => false
  elsif opts[:to_json] then
    xml = render_to_string(:template => opts[:to_json], :layout => false)
    content = Hash.from_xml(xml).to_json
    cbparam = params[:callback] || params[:jsonp]
    content = "#{cbparam}(#{content})" unless cbparam.blank?
    render :json => content, :layout => false
  else
    super opts, &block
  end
end
~~~

As you can see, we render a single XML view, and then load it to a hash from XML, and use Rails' built-in `Hash#to_json` and `Hash#to_yaml` methods to provide the data in the desired format. There is a single glaring problem with this approach, though - `Hash#from_xml` is <em>dog slow</em> because it uses REXML. There's a fantastic solution, though!

Courtesy of a blog post over at <a href="http://www.visnup.com/entries/423-cobravsmongoose-not-slow-vs-hashfrom_xml-slow-vs-faster_xml_simple-fast">cobravsmongoose</a>, we have a libxml drop-in for `Hash#from_xml`

First, install <a href="http://libxml.rubyforge.org/">libxml</a> and then <a href="http://code.google.com/p/faster-xml-simple/">faster\_xml\_simple</a>.

Second, include a monkeypatch to `Hash#from_xml` with the following:

~~~ruby
require 'faster_xml_simple'
class Hash
  def self.from_xml(xml)
    undasherize_keys(typecast_xml_value(FasterXmlSimple.xml_in(xml,
      'forcearray'   => false,
      'forcecontent' => true,
      'keeproot'     => true,
      'contentkey'   => '__content__')
    ))
  end
end
~~~

You can run the benchmarks if you'd like, but it's orders of magnitude faster than REXML. Seriously. Don't use REXML. It's like trying to run a Ferrari off of a 9-volt battery.

Now, let's say you have an action you want to provide HTML, XML, JSON, and YAML views for.

~~~ruby
def index
  ...
  respond_to do |wants|
    wants.html
    wants.xml  { render :layout => false }
    wants.json { render :to_json => "posts/index.xml.builder" }
    wants.yaml { render :to_yaml => "posts/index.xml.builder" }
  end
end
~~~

Finally, throw together your `index.xml.builder` file as you best see fit.

~~~ruby
xml.instruct! :xml, :version=>"1.0", :encoding=>"UTF-8"
xml.posts do
  @posts.each do |post|
    xml.post(:id => post.id) do
      xml.user(:id => post.user.id) +
      xml.content do
        post.post_body
      end
    end
  end
end
~~~

And all of a sudden, bam! You've got your posts available in HTML...

    /posts/index

...and in XML, YAML, and JSON, along with the associated User. By using an XML builder, you can make the serialized data as complex and customized as you'd like. No more funky respond_to blocks, no more exposing data you don't want to. Expose what you want, and just what you want, in several formats.

    /posts/index.xml
    /posts/index.yml
    /posts/index.json

One final trick is that the JSON views accept an optional `callback` or `jsonp` parameter, which will cause the content to be passed to a Javascript function matching the passed parameter, as per the <a href="http://ajaxian.com/archives/jsonp-json-with-padding">JSONP</a> spec.

For example, if you have a `/foo/bar.json` view that would render the following JSON:

    "{\"foo\":\"bar\"}"

Calling `/foo/bar.json?jsonp=returnFunc` would return the following:

    returnFunc("{\"foo\":\"bar\"}")

Check out the <a href="http://ajaxian.com/archives/jsonp-json-with-padding">JSONP</a> spec for more.
