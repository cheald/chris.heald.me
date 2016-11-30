---
layout: post
title: 'MongoDB: Warts and wobbles'
categories:
- MongoDB
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '356646075'
---
I'm a huge fan of <a href="http://www.mongodb.org/">MongoDB</a> - after years in MySQL, Interbase, and Postgres SQL databases, it was quite a breath of fresh air to get to try a document database on for size. I've more or less adopted it as my default data store for web applications, due to a number of awesome features that many people have enumerated elsewhere. Rather than yet-another post about why MongoDB is great, I figured I'd talk about the things I don't like in it, the places I've had difficulty with it, and the things I'd like to see improve. Knowing the sticky parts of a piece of technology is often as valuable - if not moreso - than knowing what it does really well. I absolutely still recommend it as a data store, but it's not a magical panacea, and I want to take a realistic view of it.

<h1>Wart #1: Case sensitivity</h1>

All data in MongoDB is case-sensitive. This is in stark contrast to something like MySQL, where indexed text columns are case-insensitive. So, if you have a "username" field, "Chris" and "chris" could be two different users, and a user trying to log in as "chris" by tying "CHRIS" into the username field would fail their login attempt. You can solve this by either a) forcing a consistent casing (lower or upper) on the column, or b) by keeping a second shadow column with normalized (and indexed) data. So, for example, I might need to keep two columns, `username` and `shadow_username`, then index and do all queries against `shadow_username`, but display `username`. This isn't a huge wart, but it's going to bite you in the ass if you aren't used to it.

<h1>Wart #2: Aggregate queries</h1>

SQL databases do aggregate queries <em>really</em> well. Consider a use case I had recently: I needed to find all accounts with duplicate emails.

In SQL, this is:

~~~sql
SELECT email, count(id) as ct FROM users HAVING ct > 1 GROUP BY email;
~~~

In MongoDB, you have to do this with a map/reduce/finalize:

~~~javascript
var map = function() {
  if(this.email) {
    emit(this.email.toLowerCase(), {count: 1})
  }
}

var reduce = function(key, values) {
  var r = {count: 0};
  for(var i=0; i<values.length; i++) {
    r.count += values[i].count;
  }
  return r;
}

db.users.mapReduce(map, reduce, {out: 'users.group_by_email'})
db.users.group_by_email.find({"value.count": {$gt: 1}})
~~~

There are two warts here - the first is that as of MongoDB 1.7.4, you no longer have the option for temporary collections in MongoDB, and so you have to either A) write the whole result to a new collection, or B) return the whole result as a single document, but limited to 16MB of data. This means more maintenance - cleaning up old collections, notably. Secondly, it's obviously a lot more code. The fact that M/R queries are written in Javascript is cool, but it's kind of a pain in the ass to crank out a one-liner. Fortunately, because you are encouraged to store denormalized data in MongoDB, you don't have to do as many of these sorts of queries, but when you do, it's noticeably more painful than it would be with SQL.

<h1>Wart #3: Timestamp sorting</h1>

This is more of a bug than a design flaw, but it's a nasty bug. MongoDB stores dates as `unsigned long long`, which is great, right? It gives you seriously far-future dates!

Until you want to sort a resultset by date that includes dates before 1970, that is (like, say, birthdays).

Since the storage type is unsigned, dates before the UNIX epoch get stored as very, very large numbers rather than as small negative numbers. You don't notice this when you're just querying data, but if you try to sort on a date column, any dates before 1970 will appear as being later than your other "normal" dates.

You might want to find all users who are more than 60 years old:

~~~javascript
db.users.find({birthday: {$lt: [Date Object for 60 years ago]}})
~~~

You'll get an empty result set, because 60 years ago, in UNIX time, is -582954786, but you won't ever have any results with a birthday indexed with a value of less than 0.

Likewise, if you want to get all users younger than a certain date:

~~~javascript
db.users.find({birthday: {$gt: [Date Object for 13 years ago]}})
~~~

You will get all users who were born before 1970 in this result set, since the index is simply looking at numeric long ranges, and pre-1970 dates will index very far future dates instead. <a href="https://jira.mongodb.org/browse/SERVER-405">This is fixed as of July 6th</a>, but won't make it into production until Mongodb 1.10.

Workarounds:

* Map/Reduce users' ages into a separate collection periodically (once a month, perhaps?), then query off of that new collection.
* Add some arbitrary amount of time to all birthdays in your application logic. For example, for birthdays, store the given birthday + 120 years, and then subtract 120 years before doing any calculations app-side with the birthday. This is an ugly hack, but requires no m/r maintenance.

<h1>Wart #4: Arbitrary Javascript operations obtain a global lock</h1>

Yesterday, I needed to fix a data problem; emails needed to be unique in my DB, but to check them, I needed a normalized lowercase email to query for. To do this, I had a simple bit of Javascript to execute:

~~~javascript
db.users.find().forEach(function(obj) {
  if(obj.email) {
    obj.email = obj.email.toLowerCase();
    db.users.save(obj);
  }
});
~~~

Easy enough. Iterate each record, lowercase the email, save the record. Except when you give it a few hundred thousand records, with a bunch of indexes on the collection, it's slooooow. My first naive crack at this locked my MongoDB master for several minutes, and didn't complete before I killed it. During that time, the app was completely unresponsive. Oops.

I was able to rewrite the migration to be a lot faster, but you have to take a lot of care when running arbitrary data migrations, since you really can shoot yourself in the face easily with it.

~~~javascript

db.users.find().forEach(function(obj) {
  if(obj.email) {
    var email = obj.email.toLowerCase();
    if(email != obj.email) {
      db.users.update({_id: obj._id}, {$set: {email: email}});
    }
  }
});
~~~

By a) only updating the record if the email changed, and b) using the atomic $set rather than updating the whole record, my migration ran in less than a second, rather than locking the entire application for minutes on end.

Be wary of that global lock. The official docs warn you about it, but the implications can't be understated. Improvements to it are coming, but you're going to nutpunch yourself with it eventually if you aren't careful.

<h1>Wart #5: $or queries and index hints</h1>

MongoDB supports the $or operator for easy query unions, which makes life nice a lot of respects. However, it completely jacks up the query optimizer if you introduce sorting. What happens is that the query optimizer decides to use the sort field for the index, and results in a full table scan for each of your $or queries! Consider the following:

~~~javascript
db.videos.find({$or: [{tags: {$all: ['b', 'a']}}, {tags: {$all: ['c', 'd']}}]})
~~~

This will find the union of all documents that have tags "b" and "a" OR "c" and "d". The tags index is used per subquery, resulting in a fast query.

But if you want to sort the results...

~~~javascript
db.videos.find({$or: [{tags: {$all: ['b', 'a']}}, {tags: {$all: ['c', 'd']}}]}).sort({title: -1})
~~~

MongoDB ignores the tags index for each of your $or clauses, and instead chooses to use the title index. This means that each of your $or clauses invokes a full table scan to find the tag matches, resulting in an extremely slow query. There is no way, as of right now, to tell the query optimizer to use the tags index when also using a sort on the cursor. Oops.

The accepted solution, right now, is to perform an in-app sort of the result set, which is a giant pain in the ass if you can't prune the unsorted resultset to a reasonable size before sending it to the app before sorting. If in-app sorting isn't an option for whatever reason, you'll have to restructure your data to avoid the $or clause.

<h1>A wobble: Document size</h1>

One of MongoDB's strengths can also be a weakness, if you're not careful. Because you can store so much denormalized data in a single record, you can drastically reduce your number of queries, and build pages faster. However, it's easy to forget that when you store all that data, you have to move it over the wire. Consider something like the following document:

~~~javascript
topic: {name: 'Topic', description: 'A bit about this topic', followers: [array of follower BSON IDs]}
~~~

This will work just fine in development. But what about in production, when that popular topic has 85,000 followers? All of a sudden, that's 1,020,000 bytes that have to be sent over the wire every time you query that topic. What this really is is the old `SELECT *` problem, but magnified 100x. It's ridiculously easy to accidentally end up with pages that are pulling tens of megabytes of data from the database server for every request, which does not scale well at all. Be judicious in your use of the field selection parameter when querying your database - your app will thank you.

To omit the followers array, I just omit the fields I don't want in the query:

~~~javascript
db.topics.find({name: 'Topic'}, {followers: false})
~~~

Just a few little tweaks like this realized massive performance gains in my app, once I wasn't moving tens of megabytes and instantiating thousands of BSON::ObjectId objects per record.

<h1>Wrapping Up</h1>

Despite the warts, none of these are reasons to decide to not use MongoDB. They introduce more work for you, and will make you pull your hair out in frustration if you naively wander into one of them by mistake, but if you're aware of them, you can avoid them, and get all the good parts without having to taste too much of the bad. Like any piece of software, MongoDB has quirks and irritations, but if you aren't buying into the hype that it's a magical web-scale fix-all that mysteriously makes database and query design a non-issue, they aren't that big of a deal. After all, now you know, and...

<a href="http://www.coffeepowered.net/wp-content/uploads/2011/07/knowing-is-half-the-battle1.jpg"><img src="http://www.coffeepowered.net/wp-content/uploads/2011/07/knowing-is-half-the-battle1.jpg" alt="" title="knowing-is-half-the-battle1" width="395" height="192" class="aligncenter size-full wp-image-447" /></a>
