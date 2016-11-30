---
layout: post
title: Serving files out of GridFS
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '334759618'
---
<a href="http://www.mongodb.org/display/DOCS/GridFS+Specification">GridFS</a> is a nifty little feature in <a href="http://www.mongodb.org/display/DOCS/Home">MongoDB</a> that allows you to store files of all shapes and sizes in Mongo itself, getting the benefits of Mongo's sharding and replication. However, since they're in a database, and not on the filesystem directly, how do we serve them?

There are lots of benchmarks and numbers under the cut. Keep reading!

Right now, there are three options:

1. Use a "low-level" script handler, like a Rack script or Rails Metal handler to serve them out of the database
1. Use something like <a href="http://github.com/mikejs/gridfs-fuse/">gridfs-fuse</a> to mount the database as a filesystem, and read it with the Fileserver directly
1. Use something like <a href="http://github.com/mdirolf/nginx-gridfs">nginx-gridfs</a> to talk directly to MongoDB from your webserver.

I wasn't able to get gridfs-fuse to build on my system, but I was able to build the nginx module. The question, of course, is how fast are you going be serving files with each solution?

<h2>Filesystem read through Apache</h2>

First, I'll establish a baseline. I'm running Apache as my frontend server, and we'll use ab to benchmark its throughput.

~~~bash
[chris@polaris conf]# ab -n 50000 -c 10 http://advice/images/embed/alliance-60.png

Server Software:        Apache/2.2.13
Server Hostname:        advice
Server Port:            80

Document Path:          /images/embed/normal_alliance-60.png
Document Length:        31596 bytes

Concurrency Level:      10
Time taken for tests:   1.904 seconds
Complete requests:      5000
Failed requests:        0
Write errors:           0
Total transferred:      159463760 bytes
HTML transferred:       158043192 bytes
Requests per second:    2625.37 [#/sec] (mean)
Time per request:       3.809 [ms] (mean)
Time per request:       0.381 [ms] (mean, across all concurrent requests)
Transfer rate:          81767.87 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    1   0.4      1       4
Processing:     1    3   0.5      3       6
Waiting:        0    1   0.4      1       4
Total:          2    4   0.4      4       8

Percentage of the requests served within a certain time (ms)
  50%      4
  66%      4
  75%      4
  80%      4
  90%      4
  95%      4
  98%      5
  99%      5
 100%      8 (longest request)
~~~

Nice and fast, like like we'd expect.

<h2>Filesystem read through nginx</h2>

~~~bash
[chris@polaris conf]# ab -n 50000 -c 10 http://advice:81/images/embed/normal_alliance-60.png

Server Software:        nginx/0.8.33
Server Hostname:        advice
Server Port:            81

Document Path:          /images/embed/normal_alliance-60.png
Document Length:        31596 bytes

Concurrency Level:      10
Time taken for tests:   7.623 seconds
Complete requests:      50000
Failed requests:        0
Write errors:           0
Total transferred:      1590513618 bytes
HTML transferred:       1579863192 bytes
Requests per second:    6559.31 [#/sec] (mean)
Time per request:       1.525 [ms] (mean)
Time per request:       0.152 [ms] (mean, across all concurrent requests)
Transfer rate:          203763.10 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.2      0       9
Processing:     1    1   0.4      1      11
Waiting:        0    0   0.1      0       9
Total:          1    1   0.5      1      12

Percentage of the requests served within a certain time (ms)
  50%      1
  66%      1
  75%      1
  80%      2
  90%      2
  95%      2
  98%      3
  99%      3
 100%     12 (longest request)
~~~

nginx <i>screams</i>. At 6500 requests/sec, it's blisteringly fast.

<h2>GridFS read through nginx-gridfs</h2>

~~~ruby
[chris@polaris conf]# ab -n 5000 -c 10 http://advice:81/images/gfs/uploads/user/avatar/4b7b2c0e98db7475fc000003/normal_alliance-60.png

Server Software:        nginx/0.8.33
Server Hostname:        advice
Server Port:            81

Document Path:          /images/gfs/uploads/user/avatar/4b7b2c0e98db7475fc000003/normal_alliance-60.png
Document Length:        31596 bytes

Concurrency Level:      10
Time taken for tests:   4.613 seconds
Complete requests:      5000
Failed requests:        0
Write errors:           0
Total transferred:      158580000 bytes
HTML transferred:       157980000 bytes
Requests per second:    1083.88 [#/sec] (mean)
Time per request:       9.226 [ms] (mean)
Time per request:       0.923 [ms] (mean, across all concurrent requests)
Transfer rate:          33570.65 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.0      0       1
Processing:     1    9   4.7      9     103
Waiting:        1    9   4.7      9     102
Total:          2    9   4.7      9     103

Percentage of the requests served within a certain time (ms)
  50%      9
  66%      9
  75%      9
  80%      9
  90%      9
  95%      9
  98%      9
  99%     11
 100%    103 (longest request)
~~~

Definitely a lot slower, but still very respectable. 1051 requests/sec is going to be more than adequate for most purposes, particularly if fronted with a CDN.

And finally...

<h2>Rails Metal handler</h2>

The nice thing about the Rails metal handler solution is that it's easy. No recompiling, just drop the handler into your project and you're off to the races. That said...

~~~ruby
[chris@polaris nginx-gridfs]$ ab -n 250 -c 4  http://advice/images/gfs/uploads/user/avatar/4b7b2c0e98db7475fc000003/normal_alliance-60.png

Server Software:        Apache/2.2.13
Server Hostname:        advice
Server Port:            80

Document Path:          /images/gfs/uploads/user/avatar/4b7b2c0e98db7475fc000003/normal_alliance-60.png
Document Length:        31596 bytes

Concurrency Level:      4
Time taken for tests:   4.646 seconds
Complete requests:      250
Failed requests:        0
Write errors:           0
Total transferred:      7960000 bytes
HTML transferred:       7899000 bytes
Requests per second:    53.81 [#/sec] (mean)
Time per request:       74.338 [ms] (mean)
Time per request:       18.585 [ms] (mean, across all concurrent requests)
Transfer rate:          1673.10 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.1      0       1
Processing:    15   74  75.6     34     287
Waiting:        0   72  75.8     30     276
Total:         15   74  75.6     34     288

Percentage of the requests served within a certain time (ms)
  50%     34
  66%     39
  75%    139
  80%    192
  90%    201
  95%    210
  98%    239
  99%    245
 100%    288 (longest request)
~~~

I obviously ran far fewer requests this go-round. The reason is pretty obvious - running 5000 requests through the Ruby stack would have taken approximately <em>forever</em>. At 53 requests per second, this is not an attractive solution, particularly if you consider the CPU overhead that it's incurring.

<h2>Conclusions</h2>

<table class='data' border='1'>
	<tr>
		<th>Solution</th>
		<th>Requests/second</th>
		<th>% Apache FS</th>
		<th>% Nginx FS</th>
		<th>% Nginx GridFS</th>
		<th>% Apache Ruby</th>
	</tr>
	<tr>
		<td>Filesystem via Apache</th>
		<td>2625.37</td>
		<td>-</td>
		<td>40.03%</td>
		<td>242.22%</td>
		<td>4,878.96%</td>
	</tr>
	<tr>
		<td>Filesystem via Nginx</th>
		<td>6559.31</td>
		<td>249.84%</td>
		<td>-</td>
		<td>605.17%</td>
		<td>12,189.76%</td>
	</tr>
	<tr>
		<td>GridFS via nginx module</th>
		<td>1083.88</td>
		<td>41.28%</td>
		<td>16.52%</td>
		<td>-</td>
		<td>2014.27%</td>
</td>
	</tr>
	<tr>
		<td>Rails metal handler via Passenger</th>
		<td>53.81</td>
		<td>2.05%</td>
		<td>0.82%</td>
		<td>4.96%</td>
		<td>-</td>
	</tr>
</table>

If you're looking to abstract away from storing files on a filesystem, GridFS is a feasable solution. It can really crank some mean output numbers, and though it's not up to par with a raw filesystem read, also consider that in many production environments, such a raw filesystem read might be happening via an NFS or GFS share, which is going to massively degrade the performance of that request. Given the no-hassle store-and-forget-about-it solution that GridFS offers, even when faced with the challenge of multi-server replication, it seems that you can get enough performance out of it to justify it as a solution.
