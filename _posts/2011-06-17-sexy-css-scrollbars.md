---
layout: post
title: Sexy CSS Scrollbars in Chrome
categories:
- CSS
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '335536226'
---
It's like it's 1996 all over again, except with less suck. Webkit now supports styleable scrollbars, and you get to use all the Webkit CSS3 goodies, like gradients and rounded corners and the like. If you're using Chrome or Safari, you might notice that I have the blog theme rocking super sexy grey scrollbars now, which really ties the whole theme together. It's pretty easy, too.

<!--more-->

If you're just here for the code, here's the quick and dirty. I grabbed this from <a href="http://beautifulpixels.com/goodies/create-custom-webkit-scrollbar/">Beautiful Pixels</a> and adapted it to my needs.

~~~css
::-webkit-scrollbar {
  width: 13px;
  height: 13px; }

::-webkit-scrollbar:hover {
  height: 18px; }

::-webkit-scrollbar-button:start:decrement,
::-webkit-scrollbar-button:end:increment {
  height: 15px;
  width: 13px;
  display: block;
  background: #101211;
  background-repeat: no-repeat; }

::-webkit-scrollbar-button:horizontal:decrement {
  background-image: url(scrollbar/horizontal-decrement-arrow.png);
  background-position: 4px 3px; }

::-webkit-scrollbar-button:horizontal:increment {
  background-image: url(scrollbar/horizontal-increment-arrow.png);
  background-position: 3px 3px; }

::-webkit-scrollbar-button:vertical:decrement {
  background-image: url(scrollbar/vertical-decrement-arrow.png);
  background-position: 3px 4px; }

::-webkit-scrollbar-button:vertical:increment {
  background-image: url(scrollbar/vertical-increment-arrow.png);
  background-position: 3px 4px; }

::-webkit-scrollbar-button:horizontal:decrement:active {
  background-image: url(scrollbar/horizontal-decrement-arrow-active.png); }

::-webkit-scrollbar-button:horizontal:increment:active {
  background-image: url(scrollbar/horizontal-increment-arrow-active.png); }

::-webkit-scrollbar-button:vertical:decrement:active {
  background-image: url(scrollbar/vertical-decrement-arrow-active.png); }

::-webkit-scrollbar-button:vertical:increment:active {
  background-image: url(scrollbar/vertical-increment-arrow-active.png); }

::-webkit-scrollbar-track-piece {
  background-color: #151716; }

::-webkit-scrollbar-thumb:vertical {
  height: 50px;
  background: -webkit-gradient(linear, left top, right top, color-stop(0%, #4d4d4d), color-stop(100%, #333333));
  border: 1px solid #0d0d0d;
  border-top: 1px solid #666666;
  border-left: 1px solid #666666; }

::-webkit-scrollbar-thumb:horizontal {
  width: 50px;
  background: -webkit-gradient(linear, left top, left bottom, color-stop(0%, #4d4d4d), color-stop(100%, #333333));
  border: 1px solid #1f1f1f;
  border-top: 1px solid #666666;
  border-left: 1px solid #666666; }
~~~

`::-webkit-scrollbar` defines the height and width of your scrollbars for horizontal and vertical scroll bars, respectively.

`::-webkit-scrollbar-button:start:decrement` and `::-webkit-scrollbar-button:end:increment` style the arrows on either end of the scroll bar. I have mine set to 1px black bars, but you could add an image, or a gradient, or whatnot.

`::-webkit-scrollbar-track-piece` sets styles for the background of the scrollbar (called the "track" here)

`::-webkit-scrollbar-thumb:vertical` and `::-webkit-scrollbar-thumb:horizontal` set styles for the draggable portion of the scroll bar. Background images, gradients, round corners, and even box shadows are all valid here. Go nuts.

With just those pieces, you should be able to crank out awesome-looking theme-fitting scroll bars. Have fun with it!
