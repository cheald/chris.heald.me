---
layout: post
title: 'Quick tip: Strip URLs before parsing!'
categories: []
tags:
- error
- parse
- Rails
- Ruby
- uri
- usability
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '335200627'
---
Rather than roll my own URL regexes, I prefer to let the existing libraries do the heavy lifting. Ruby has a `uri` library which is fantastic for parsing (and validating) URLs.

For example, something like this might be used in a model validation:

~~~ruby
require 'uri'

def validate_url(url)
	parsed_uri = URI::parse(url)
rescue URI::InvalidURIError
	errors.add :url, "Sorry, that doesn't look like a valid URL"
end
~~~

I noticed a bit ago that I started getting invalid URL errors where there shouldn't be any. After far too long spent in the library's code, I realized my error: the URLs were being pasted with a trailing space. Stripping the string before attempting to parse it fixed it right up.

I'd argue that URI::parse should likely strip any incoming strings, but in the meantime, remember to strip your user input before trying to determine whether it's valid or not, or you may end up with frustrated users.
