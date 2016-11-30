---
layout: post
title: Restarting Resque workers (or anything, really) with Monit, Passenger-style.
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '391243456'
---
Easy way to trigger off a reload of a service managed by Monit without having to become root. In my case, I've got a monit service called resque-worker, and I can restart it by just touching `tmp/resque-restart.txt`.

    check file resque-restart.txt with path /path/to/your/app/tmp/resque-restart.txt
      if changed timestamp then
        exec "/usr/bin/monit restart resque-worker"

Ties in nicely with deploy tasks, and you don't have to end up leaving root access SSH keypairs laying around.
