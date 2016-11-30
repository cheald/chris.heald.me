---
layout: post
title: jquery-migrate and XSS
status: publish
type: post
published: true
---

We were recently flagged by a security researcher for an active XSS hole in our site. After bisecting the origin of the hole to the introduction of [jquery-migrate](https://github.com/jquery/jquery-migrate/), I put together a minimal proof-of-concept for it and spoke to Dave Methvin on the jQuery team about it. He told me that this was not, in fact, a bug, but was working as intended. To that end, I'm publishing this to warn people about the danger of jquery-migrate's divergent approach to this issue, so that you can be extra sure to sanitize your jQuery selectors.

The proof of concept is as follows:

~~~html
<script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
<script src="http://code.jquery.com/jquery-migrate-1.2.1.js"></script>
<script>
$(function() {
  x = $("a[href='" + window.location.hash + "']")
  console.log(x)
})
</script>
~~~

(This particular example is a simplification of how we were persisting in-page tab selection state in a few places; I suspect it's a semi-common use case)

You can invoke it via something like:

    http://example.com/xss-poc.html#<img src=x onerror=prompt(1)>

Or you can just invoke, from a console:

    node = $("a[href='#<img src=x onerror=prompt(1) />']")

With just bare jquery, this returns an empty set `[]` - no nodes matched the selector. When jquery-migrate is present, it constructs nodes in a documentFragment (thus letting the img's onerror fire, even if you never attach the node to the DOM), then returns the nodes, resulting in:

    [<img src=​"x" onerror=​"prompt(1)​">​]

## The Issue

The basic problem here is that jQuery has this ambiguous syntax wherein you can actually select nodes in a document:

    $("foo")

Or you can create nodes:

    $("<div id='foo'></div>")

In both cases, the `$` function is used, and the operation is inferred by the data passed to it. jquery-migrate is doing something that breaks this inference and causes jQuery to attempt to construct a node rather than applying it as a selector in the example given:

    $("a[href='<img src=x onerror=prompt(1) />']")

I was unable to reproduce this exploit using only jQuery 2.0.3, 1.10.2, 1.9.1, 1.8.3, 1.7.2, or 1.6.4. However, adding jquery-migrate to any of these immediately resulted in the application becoming vulnerable to XSS, except under 1.6.4 and 1.7.2. As far as I can tell, this is because the jQuery team wants something like this to work:

    var node = $("bare text and node <img src=x />")

and jquery-migrate somehow breaks something that causes it to misinterpret the a selector as a node construction. Given that this is divergent from the current jQuery core behavior, I'm not quite sure how it's working as intended, but I've been assured that it is, so I feel that the best course of action is to educate people on the divergent behavior.

Anyhow, all this is to say "jquery-migrate might punch XSS holes that you thought were closed". Use with caution. And, as always, sanitize your inputs; assuming that a library that is not specifically responsible for sanitization is doing the right thing may end up leaving you in the lurch when they change something and stop sanitizing things that were previously sanitized.