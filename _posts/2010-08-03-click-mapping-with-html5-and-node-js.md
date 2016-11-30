---
layout: post
title: Click mapping with HTML5 and node.js
categories:
- jQuery
- MongoDB
- node.js
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _wp_old_slug: ''
  dsq_thread_id: '334776539'
---
I was recently in need of a click mapping solution, and didn't like most of the solutions I came across. They had huge dependency chains and were generally unwieldy, or they didn't work that well, or they were external services that I had to pay for...until I ran across <a href="http://heatmapthing.heroku.com/">heatmapthing</a>. Now we're talking. Client-side rendering of JSON location data - we're in business!

First things first. If this is TL;DR for you, <a href="http://coffeepowered.net/projects/clickhax/">here's the demo</a>, or click the "Click Heatmap" button in the corner of this page.

My first iteration was an endpoint in my current Rails app, which handled saving/sending of click data. That worked fine, but for something as lightweight and common as a click, I didn't want to be invoking my full Rails stack. I've also been meaning to play with <a href="http://nodejs.org/">node.js</a>...well hey, there's an opportunity here!

First, I had to get the client code working. I modified the existing heatmap code into a jQuery plugin, which handled all the setup/transmission/rendering of data. This enables you to do something like so:

    $("#body_wrapper").clickhax({ trigger: "#showHeatmap", endpoint: "/map" });

What that does is attach the handlers to your wrapper element, and sets up the HTML5 canvas to display over that. Events will be sent to `/map` (which, in this example, is ProxyPassed to my node.js daemon), and clicking an element with an id of `showHeatmap` causes the heatmap data to be fetched and rendered on the client. The client itself just takes a raw JSON dataset and performs smoothing and rendering with it. It's fairly basic canvas work - the majority of the heavy lifting is non-graphical - but still, it'll only work in browsers that support the canvas tag. Sorry, oldschool IE users.

Okay, great, that's working, what about the backend now?

Node.js is remarkably easy to get up and running on, and with the addition of the <a href="http://expressjs.com/">Express</a> package, it behaves an awful lot like Sinatra. I'm using MongoDB as my backend store for this, which is handy, since it natively speaks JSON, and there are client libraries for node. Using the npm utility, I quickly had them installed and was up and running.

You can <a href="http://github.com/cheald/clickhax/blob/master/clickhax-daemon.js">see the code on GitHub</a>, but I'll touch on the key points here first.

The biggest gotcha I ran into this was in my treatment of the database connection handling. It took me a little while to recognize that the calls being made are **asynchronous**. This is important. This is *very important*. Rather than writing it top-down like a Ruby script, I had to, as you can see, use the provided callback chains. In particular, in my get("/") handler, I was performing the query and then immediately trying to iterate the cursor - this doesn't work! You have to iterate in the callback. (In my defense, it was late and my brain was foggy!)

The code is pretty straightforward, though. When you post to your endpoint, it accepts x and y parameters and parses out the referring URL as the click target page. The plugin computes the click as an offset from the top left corner of your wrapped element, so if you have a fixed-width wrapper, your click data remains consistent even with differing monitor sizes. Data is quantitized to 5px before storage, and storage is done with upserts and MongoDB's atomic increment; multiple clicks in the same 5px square will simply increment a counter in that record, rather than saving a record per click.

Positions are indicated by assuming a maximum width of 3000px. This allows us to store positions as single integers, rather than position pairs or strings. The client plugin is aware of this, and can reverse a given index into an x/y pair accordingly. The getter simply constructs a hash of `{position: click_count}` and sends that to the client. The client then applies a blur pattern on top of those points to generate a smoothed heightfield, and then normalizes that heightfield to the 0..255 range. Those heights are then mapped to colors and rendered onto the canvas. That's all there is to it!

Quantitizing to 5px squares means that for my 600x400 demo, I have 9600 potential squares, and each square takes 6-11 bytes of JSON to represent. Thus, even for a fully saturated clickmap, I should only ever have to receive/compute/render 103kb worth of data. That number of obviously increases as you increase the size of the target area - 960x2000 would be a maximum of 825kb of data for a fully saturated clickmap. However, in practice, full saturation should be a non-concern. Your clicks will be focused around interactable elements, and due to the atomic increment counters, heatmaps should remain light and snappy both for inserts and fetches, regardless of the number of clicks in a page.

If you don't already have node.js and mongodb, the setup may be a bit more involved, but you could use PHP/MySQL, or Rails with SQLite or whatever as your endpoint server. The front and back ends are relatively decoupled, and can be re-used independently of each other.
