---
layout: post
title: Setting up replica sets with MongoDB 1.6
categories:
- MongoDB
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  _wp_old_slug: ''
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '334986763'
---
<h3>Introduction</h3>

<a href="http://www.mongodb.org/">MongoDB</a> 1.6 <a href="http://www.mongodb.org/downloads">was released today</a>, and it includes, among other things it includes support for the incredible sexy <a href="http://www.mongodb.org/display/DOCS/Replica+Sets">replica sets feature</a> - basically master/slave replication on crack with automatic failover and the like. I'm setting it up, and figured I'd document the pieces as I walk through them.

My test deploy is going to consist of two nodes and one arbiter; production will have several more potential nodes. We aren't worrying about sharding at this point, but 1.6 brings automatic sharding with it, as well, so we can enable that at a later point if we need to.

<h3>Installation</h3>

Installation is very easy. 10gen offers a <a href="http://www.mongodb.org/display/DOCS/CentOS+and+Fedora+Packages">yum repo</a>, so it's as easy as adding the repo to `/etc/yum.repos.d` and then running `yum install mongo-stable mongo-server-stable`.

Once installed, `mongo --version` confirms that we're on 1.6. Time to boot up our nodes.

<h3>Configuration</h3>

For staging, we're going to run both replica nodes and the arbiter on a single machine. This means 3 configs.

I have 3 config files in `/etc/mongod/` - `mongo.node1.conf`, `mongo.node2.conf`, and `mongo.arbiter.conf`. As follows:

    # mongo.node1.conf
    replSet=my_replica_set
    logpath=/var/log/mongo/mongod.node1.log
    port = 27017
    logappend=true
    dbpath=/var/lib/mongo/node1
    fork = true
    rest = true

    # mongo.node2.conf
    replSet=my_replica_set
    logpath=/var/log/mongo/mongod.node2.log
    port = 27018
    logappend=true
    dbpath=/var/lib/mongo/node2
    fork = true

    # mongo.arbiter.conf
    replSet=my_replica_set
    logpath=/var/log/mongo/mongod.arbiter.log
    port = 27019
    logappend=true
    dbpath=/var/lib/mongo/arbiter
    fork = true
    oplogSize = 1

<h3>Starting it up</h3>

Then we just fire up our daemons:

    mongod -f /etc/mongod/mongo.node1.conf
    mongod -f /etc/mongod/mongo.node2.conf
    mongod -f /etc/mongod/mongo.arbiter.conf

Once we spin up the servers, they need a bit to allocate files and start listening. I tried to connect a bit too early, and got the following:

~~~bash
[root@261668-db3 mongo]# mongo
MongoDB shell version: 1.6.0
connecting to: test
Fri Aug  6 03:48:40 Error: couldn't connect to server 127.0.0.1} (anon):1137
exception: connect failed
~~~

<h3>Configuring replica set members</h3>

Once you can connect to the mongo console, and we need to set up the replica set. If you have a compliant configuration, then you can just call `rs.initiate()` and everything will get spun up. If you don't, though, you'll need to specify your initial configuration.

This is where I hit my first problem; the hostname as the system defines it didn't resolve. This was resulting in the following:

~~~js
[root@261668-db3 init.d]# mongo --port 27017
MongoDB shell version: 1.6.0
connecting to: 127.0.0.1:27017/test
> rs.initiate();
{
        "info2" : "no configuration explicitly specified -- making one",
        "errmsg" : "couldn't initiate : need members up to initiate, not ok : 261668-db3.db3.domain.com:27017",
        "ok" : 0
}
~~~

The solution, then, is to specify the members, and to use a resolvable internal name. Note that you do NOT include the arbiter's information; you don't want to add it to the replica set early as a full-fledged member.

~~~js
> cfg = {_id: "my_replica_set", members: [{_id: 0, host: "db3:27017"}, {_id: 1, host: "db3:27018"}] }
> rs.initiate(cfg);
{
        "info" : "Config now saved locally.  Should come online in about a minute.",
        "ok" : 1
}
~~~

Bingo. We're in business.

<h3>Configuring the replica set arbiter</h3>

If the replica set master fails, a new master is elected. To be elected, a replica master needs to have at least floor(<em>n</em> / 2) + 1 votes, where <em>n</em> is the number of active nodes in the cluster. In a paired setup, if the master were to fail, then the remaining slave wouldn't be able to elect itself to the new master, since it would only have 1 vote. Thus, we run an arbiter, which is a special lightweight, no-data-contained node whose only job is to be a tiebreaker. It will vote with the orphaned slave and elect it to the new master, so that the slave can continue duties while the old master is offline.

~~~js
> rs.addArb("db3:27019")
{
        "startupStatus" : 6,
        "errmsg" : "Received replSetInitiate - should come online shortly.",
        "ok" : 0
}
~~~

<h3>Updated driver usage</h3>
Once we're set up, the Ruby Mongo connection code is updated to connect to a replica set rather than a single server.

Before:

~~~ruby
MongoMapper.connection = Mongo::Connection.new("db3", 27017)
~~~

After

~~~ruby
MongoMapper.connection = Mongo::Connection.multi([["db3", 27017], ["db3", 27018]])
~~~

This will attempt to connect to each of the defined servers, and get a list of all the visible nodes, then find the master. Since you don't have to specify the full list, you don't have to update your connection info each time you change the machines in the set. All it needs is at least one connectable server (even a slave) and the driver will figure out the master from there.

<h3>Conclusion</h3>

That's about all there is to it! We're now up and running with a replica set. We can add new slaves to the replica set, force a new master, take nodes in the cluster down, and all that jazz without impacting your app. You can even set up replica slaves in other data centers for zero-effort offsite backup. If your DB server exploded, you could point your app at the external datacenter's node and keep running while you replace your local database server. Once your new server is up, just bring it online and re-add its node back into your replica set. Data will be transparently synched back to your local node. Once the sync is complete, you can re-elect your local node as the master, and all is well again.

Congratulations - enjoy your new replica set!
