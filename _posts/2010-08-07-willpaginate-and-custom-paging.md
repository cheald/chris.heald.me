---
layout: post
title: WillPaginate and custom paging.
categories:
- Rails
- Ruby
tags:
- will_paginate
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  _wp_old_slug: ''
  dsq_thread_id: '335200666'
---
<a href="http://wiki.github.com/mislav/will_paginate/">will_paginate</a> is the de facto Rails paging plugin, and with good reason - it's solid, fast, and reliable. Everyone I know uses it, but a lot of people don't use it to its full power.

I recently discovered some <em>very</em> cool functionality it includes - the `WillPaginate::Collection` class can be used as a custom paginator for effectively any enumerable collection. It's very simple, too. I recently used it to build pages of the most popular tags on posts in my database. My data store is MongoDB, and I'm fetching an array consisting of two-element arrays, `[tag, tag_count]`. To use will_paginate's functionality with this, I just use the following:

~~~ruby
tags = Post.tag_counts(nil, {:sort => ["value", "descending"]}) # Return an array of tag/count pairs. Custom function, so it can't leverage the finder on Post.
@topics = WillPaginate::Collection.create(current_page, 20, tags.length) do |pager|
	pager.replace(tags.slice(pager.offset, pager.offset + pager.per_page))
end
~~~

`current_page` is a helper that derives the current page from the request parameters. The rest of it is self-explanitory. I can now use `@topics` in my page just as I'd use a paginated result set from the database.

~~~ruby
- @topics.each do |topic|
    # ...
=will_paginate @topics
~~~

Bam. Doesn't get much easier than that. You can get exceptionally creative with it, too. Effectively, all you need to know is:

* `WillPaginate::Collection#new` takes 3 parameters: the current page, the per-page count, and optionally, the total number of entries.
* The `pager` block variable exposes `offset` and `per_page` properties, prime for passing into a DB query or slicing an enumerable with
* Call `pager.replace(sub-array)` with the current page's set of elements.

That's literally all there is to it. Now you can have easy pagination on just about any collection you can conceive of. Let WillPaginate handle all the heavy lifting and such. If you've done enough pagination by hand, you'll probably appreciate the easy beauty of this particular method.
