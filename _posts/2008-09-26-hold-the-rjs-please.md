---
layout: post
title: Hold the RJS, please.
categories:
- Rails
- Ruby
tags:
- erb
- javascript
- rjs
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '337763456'
---
Rails does a great job at many things, but one of the most consistent stumbling blocks I see in <a href="http://wiki.rubyonrails.org/rails/pages/IRC">#rubyonrails</a> is RJS. It complicates many things that just don't need to be that complex, especially when using a Javascript helper library like <a href="http://prototypejs.org/">Prototype</a> or <a href="http://jquery.com/">jQuery</a>.

Keep things simple! One little helper, and your AJAX requests get a whole lot easier to manage. This was inspired by the now-defunct <a href="http://www.danwebb.net/2006/11/24/minusmor-released">MinusMOR</a>.

~~~ruby
def js(data)
  data.respond_to?(:to_json) && data.to_json || data.inspect.to_json
end
~~~

Now, when you want to render a Javascript view, you can use just straight Javascript. For example, if you would like to update a given element in your page with the contents of a partial, save a template, something like `update.js.erb`, with the following:

~~~erb
$("div#post_<%=@post.id%>").update(<%=js render(:partial => "post.html.erb", :object => @post) %>);
~~~

This is admittedly more complex than RJS in the simple case, but what about when you want to do more complex stuff, like this `vote.js.erb` template?

~~~erb
<% unless @msg.nil? %>
statusMessage(<%=js @msg%>);
<% end %>
var obj = $$('div#post_<%=@post.id%> span.vote a');
for(var i=0; i<obj.length; i++) {
	var e = obj[i];
	e.update(<%=js "+#{@post.vote_score}"%>);
	e.addClassName("voted_post");
}
~~~

Just as easy as writing any of your other views, and won't get in your way when you need to go some fancy Javascript gymnastics without requiring ugly heredocs cluttering up the code all over.

How about passing an `Array` to a client-side Javascript function?

~~~erb
runSomeUpdateFunctionThatTakesAJavascriptArray(<%=js @list_of_values %>)
~~~

No worries about malformed Javascript!
