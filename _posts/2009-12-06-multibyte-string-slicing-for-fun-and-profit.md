---
layout: post
title: Multibyte string slicing for fun and profit
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
  dsq_thread_id: '335200648'
---
Ran into a small issue in one of my user models. I was using a helper to display a user's first name, last initial. It looked something like this:

~~~ruby
def display_name(user)
  "user.first_name #{user.last_name.slice(0,1)}"
end
~~~

Seems innocent enough, sure. Except...it doesn't work in multibyte character sets. The first Cyrillic speaker to sign up blew that all up. When parsing an XML fragment with a name like this included, I was getting the following error: 

~~~ruby
ActionView::TemplateError: premature end of regular expression: /^\s*Елена\ �/

nokogiri (1.4.0) lib/nokogiri/xml/fragment_handler.rb:53:in `characters'~~~

The issue, as it turned out, is that String#slice is a bytewise operation, not a character-wise operation like I'd so naively assumed. The issue is pretty easily to observe:

~~~ruby>> "Журинова".slice(0, 1)
=> "\320"~~~

Fortunately, Rails has multibyte support baked in already, so it's an easy mistake to correct:

~~~ruby
def display_name(user)
  "user.first_name #{user.last_name.chars.first}"
end
~~~

And now...

~~~ruby
>> "Журинова".chars.first
=> "Ж"
~~~

It's very easy to make mistakes like this, and many times you may not even realize that they're made unless you try to do something funny, like using it as a part of a regex. The safe operation is to never use String#slice or string subscripting on user data, but to instead treat all strings as multibyte strings. Very subtle, but the effects can be pretty nasty if you don't.
