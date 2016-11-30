---
layout: post
title: MongoDB, count() and the big O
categories:
- MongoDB
- Performance
- Ruby
tags:
- mongomapper
- plucky
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '360990461'
---
MongoDB, as I've mentioned before, is not without its warts. I've run into another, and it's a nasty one. It turns out that if you perform `count()` on a query cursor that includes any conditions, even if those conditions are indexed, the operation takes <strong>O(n)</strong> time to run. 

In practice, I've found that this costs about 1ms per 1000 records in your counted result set. This is <i>really</i> bad in concert with <a href="https://github.com/mislav/will_paginate">will_paginate</a>, which <a href="https://github.com/jnunemaker/plucky">Plucky</a> (which is used by <a href="http://mongomapper.com/">MongoMapper</a>) exposes an interface to. It naively takes your query, performs a `count()` on it, and then performs the query <em>again</em> with limiters to get the records for the current page. This is a standard and quickly-accepted way to do this sort of thing.

NewRelic is a great tool to help profile your applications, and in this case, it's making the problem abundantly clear:

<a href="http://www.coffeepowered.net/uploads/2011/07/plucky.png"><img src="http://www.coffeepowered.net/uploads/2011/07/plucky.png" alt="" title="NewRelic readout" width="100%" class="size-full wp-image-457" /></a>

You see that purple? That's how long it takes to run those `count()` operations. What a big fat pile of suck.

I don't have a good solution to this yet, but in the meantime, I've mokneypatched Plucky to cache counts for large result sets. This means that my total counts for a large collection might desync over the course of an hour, but in my use cases, I only need ballpark numbers, so it works out well. This has a very noticeable effect on page times, effectively halving the amount of time I spend in the database for a given index page. Additionally, I can manually specify a count. So, for example, if I know a collection will have over 10k results, I can just pass 10k, and stop paginating after 10k results, drastically reducing my DB load at the expense of exposing older or long-tail content (which may be perfectly, appropriate, depending on the application context).

What I'm doing is caching any counts over some arbitrary limit (I chose 10k, at which point the counts would take ~10ms) for an hour via the Rails cache (memcached, in my case, leveraging the `expires_in` parameter). I brought the issue up in the #mongodb IRC channel, and the advice I was given was basically "cache your counts", which is all well and good for simple data sets, but when I'm building pages per-user based on their preferences and myriad inputs (all indexed, mind you), it just doesn't work, so I've resorted to this. It's a hack, but it's gotten my page times down substantially.

~~~ruby
module Plucky
  class Query
    BIG_RESULT_SET = 10000

    def paginate(opts={})
      page          = opts.delete(:page)
      limit         = opts.delete(:per_page) || per_page
      query         = clone.update(opts)
      cache_key     = "count-cache-#{criteria.source.hash}"
      total         = opts.delete(:total) || Rails.cache.read(cache_key)
      if total.nil?
        total       = query.count
        if total > BIG_RESULT_SET
          Rails.cache.write(cache_key, total, :expires_in => 1.hour)
        end
      end
      paginator     = Pagination::Paginator.new(total, page, limit)
      query[:limit] = paginator.limit
      query[:skip]  = paginator.skip
      query.all.tap do |docs|
        docs.extend(Pagination::Decorator)
        docs.paginator(paginator)
      end
    end
  end
end
~~~

I'm not entirely happy with this solution, and would love input on ways to fix it.
