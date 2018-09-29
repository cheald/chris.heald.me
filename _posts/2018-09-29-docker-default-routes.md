---
layout: post
title: Docker & Default Routes
categories:
- Docker
- Devops
tags: []
status: publish
type: post
published: true
---

## TL;DR

If you have multiple networks attached to your container, make sure your first network lexically sorts before the others you attach, or your default gateway will change, which breaks all kinds of things.

## The Long Version

Lately I've been working on blue-green deployment processes with Docker. It's a simple enough idea: bring up a container, make sure it's healthy, and then turn on network routing for it. This is especially important when "container up" doesn't mean "application in the container is ready" (basically any Rails or Java app, for example).

The basic structure of my setup is:

* [nginx-proxy[(https://github.com/jwilder/nginx-proxy) on each Docker host runs on a known port, and the LB proxies to it
* Containers are brought up with a VIRTUAL_HOST environment variable, which instructs nginx-proxy to rewrite its nginx config and reload, so it can now route to the new container.

This is a problem when the container isn't quite ready, because nginx can be reloaded before the application is answering. This results in at least 1 request stalling failing, and depending on upstream nginx configs, can end up blacklisting the entire backend (or docker host, in the LB's case) for a timeout period.

So, to solve this, I'm using the typical back/front network setup:

* nginx-proxy is attached to the docker bridge network.
* nginx-proxy is also attached to each application's front network, `app_stage`.
* Each container is brought up in its back network, `app_stage_internal` and health checked.
* Once the application is healthy, the container is attached to the front network, `app_stage`.
* We kick off the nginx config scan/rewrite/reload, and nginx should start routing traffic.

Not that hard, right? Except...well, it didn't work. The first few requests after attaching the front network to the container would stall. If I had open long-running connections (Redis and Websockets were the biggest offenders), then they just remained open but never received any data. They were connected, but effectively dead. What on earth was going on? If I used just one network, it wasn't a problem. I'd begun to wonder if Docker's `network connect` mechanism was broken in some way that either everyone knew about and didn't talk about, or if I just had a broken setup. I couldn't find any reference to anyone else having any problem like this.

I finally stumbled into the solution using [netshoot](https://github.com/nicolaka/netshoot) to inspect every metric I could think of. I noticed that when I'd bring up my containers with this mechanism, I'd get something like:

```s
 [1] 🐳  → route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         172.24.34.1     0.0.0.0         UG    0      0        0 eth0
172.24.34.0     *               255.255.255.0   U     0      0        0 eth0
```

And then when the second network was attached:

```s
 [1] 🐳  → route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         172.24.35.1     0.0.0.0         UG    0      0        0 eth1
172.24.34.0     *               255.255.255.0   U     0      0        0 eth0
172.24.35.0     *               255.255.255.0   U     0      0        0 eth1
```

Wait, _what_? Why was the default gateway changing after connecting a second NIC?

It turns out the answer is [right there in the documentation](https://docs.docker.com/v17.09/engine/userguide/networking/):

> You can connect and disconnect running containers from networks without restarting the container. When a container is connected to multiple networks, its **external connectivity is provided via the first non-internal network, in lexical order**.

Wow, okay. Your default gateway becomes whichever network _appears first in a list sorted by name_. Yikes.

The fix was easy enough. Rather than using `app_stage` and `app_stage_internal`, I just switched my network naming convention to `BACK_app_stage` and `FRONT_app_stage`. That way, the front networks always sort after the back networks and don't take over as the default gateway when a new network is attached. It'd also work to make the back network internal, but since my containers do occassionally depend on external network connectivity to come up (I'm [looking at you, Passenger](https://www.phusionpassenger.com/library/indepth/security_update_check.html)), my team needs back networks to be able to get to internet.

I did find [this issue](https://github.com/moby/moby/issues/20179) which describes the problem (and asks for a fix), but it's been open for about 2.5 years now. A better fix would be some way to specify the metric of the new interface during `docker network connect`, but I can't find any way to do that, either. A third option would be to just use `ip` in the container to rejigger the default route, but that's also a no-go since the ip tool may not be available in every container.
