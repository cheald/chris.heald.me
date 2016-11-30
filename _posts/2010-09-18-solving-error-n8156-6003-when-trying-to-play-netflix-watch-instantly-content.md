---
layout: post
title: Solving error n8156-6003 when trying to play Netflix Watch Instantly content.
categories: []
tags:
- drm
- n8156-6003
- netflix
- watch instantly
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _wp_old_slug: ''
  dsq_thread_id: '334799946'
---
This is mostly search engine bait, because I couldn't find a solution on my own when searching, but managed to stumble across it anyhow.

I recently did a Windows 7 x64 reinstall, and after doing so, Netflix wouldn't play in any of my clients - Windows Media Center, Chrome, IE, you name it. After various solutions (DRM reset, security component upgrade, Silverlight uninstall and reinstall), it turns out the solution is stupidly easy:

1. Run your browser as an Administrator. (Right click, Run as Administrator)
2. Open Netflix and start watching a movie.
3. Once it successfully starts playing, close your Administrator browser.
4. Open a normal browser session and resume watching whatever you'd like to watch.

I can only guess that some initial setup doesn't get done properly, and it fails if you're trying to do the initial license acquisition in a non-elevated program. Hopefully this saves someone else a headache!
