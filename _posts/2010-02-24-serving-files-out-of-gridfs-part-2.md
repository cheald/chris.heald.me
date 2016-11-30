---
layout: post
title: Serving files out of GridFS, part 2
categories:
- MongoDB
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '334770620'
---
Since my initial experiments with <a href="http://www.mongodb.org/display/DOCS/GridFS+Specification">GridFS</a> and <a href="http://github.com/mdirolf/nginx-gridfs">nginx-gridfs</a>, I discovered a rather downer of a dealbreaker: compiling <a href="http://www.modrails.com/">Passenger</a> and nginx-gridfs into the same <a href="http://nginx.org/">nginx</a> binary makes nginx very unhappy. It hard-freezes (as in, blocks forever) when you request a GridFS file with Passenger enabled. Oops.

So, I sat down and fixed gridfs-fuse. You can grab <a href="http://github.com/cheald/gridfs-fuse">my branch at GitHub</a>. I made a few changes that make it ideal for serving files out of a GridFS DB, with a few caveats.

<h2>Installation and Configuration</h2>

Building it is relatively simple.

1. Install scons, the Python SConstruct utility (on Fedora/CentOS/RHEL, `yum install scons`)
1. Extract or symlink a copy of your <a href="http://www.mongodb.org/display/DOCS/Home">mongodb</a> install to `/opt/mongo`
1. Run `scons`
1. If all builds well, yay. If not, fix any missing dependencies or path issues. Edit SConstruct to change any paths that you need to.
1. Create a mount point for your GridFS filesystem; I used /mnt/gridfs (`sudo mkdir /mnt/gridfs`)
1. chown your mount point to your webserver's user. If you run Apache, this is probably `apache`. If you run nginx, it's probably `nobody`. (`sudo chown nobody.nobody /mnt/gridfs`)
1.  Mount the database to the mount point.

    `sudo -u nobody ./mount_gridfs --db=your_database --host=localhost /mnt/gridfs`

  Change the user and db parameters as required.
1. Configure your webserver to serve files appropriately. In my case, I have <a href="http://github.com/jnicklas/carrierwave">carrierwave</a> set up to write files to `uploads/model/_id/filename.png`, and carrierwave is configured to use `/images/gfs` as my base URL. This means that for a given file, I might end up with a path like `/images/gfs/uploads/user/avatar/4b8475cc69e0dc57e7000005/thumb_untitled-20.png`. To cause the GridFS files to be served off of the mount point, I just symlinked the mount to /images/gfs.

    ~~~bash
    cd public/images
    ln -s /mnt/gridfs gfs
    ~~~

Once that's all set up, you should be able to use your webserver to serve images directly out of your Mongo database, and at pretty fair rates, too!

<h2>143% Unscientific Benchmarks</h2>

    [chris@polaris gridfs-fuse]# ab -n 5000 -c 25 http://advice:81/images/gfs/uploads/user/avatar/4b8347a698db740b30000057/thumb_adrine-big.png

    Server Software:        nginx/0.8.33
    Server Hostname:        advice
    Server Port:            81

    Document Path:          /images/gfs/uploads/user/avatar/4b8347a698db740b30000057/thumb_adrine-big.png
    Document Length:        14332 bytes

    Concurrency Level:      25
    Time taken for tests:   5.029 seconds
    Complete requests:      5000
    Failed requests:        0
    Write errors:           0
    Total transferred:      72725000 bytes
    HTML transferred:       71660000 bytes
    Requests per second:    994.22 [#/sec] (mean)
    Time per request:       25.145 [ms] (mean)
    Time per request:       1.006 [ms] (mean, across all concurrent requests)
    Transfer rate:          14121.93 [Kbytes/sec] received

    Connection Times (ms)
                  min  mean[+/-sd] median   max
    Connect:        0    0   0.1      0       1
    Processing:    16   25   1.4     25      52
    Waiting:        2   24   1.4     24      52
    Total:         17   25   1.4     25      53

    Percentage of the requests served within a certain time (ms)
      50%     25
      66%     25
      75%     25
      80%     25
      90%     25
      95%     26
      98%     27
      99%     32
     100%     53 (longest request)

<h2>Caveats</h2>

To get this working, I had to hack in directory support. GridFS stores files with paths, but doesn't store them in a hierarchy; Fuse navigates a filesystem, which is hierarchical. In order to overcome this, I made gridfs-fuse respond to directory requests as valid. For a given file, gridfs-fuse will walk the following path hierarchy:

    GET /uploads/user/avatar/4b8347a698db740b30000057/thumb_adrine-big.png
    Check for `uploads`, directory exists
    Check for `uploads/user`, directory exists
    Check for `uploads/user/avatar/`, directory exists
    Check for `uploads/avatar/4b8347a698db740b30000057`, directory exists
    Check for `uploads/user/avatar/4b8347a698db740b30000057/thumb_adrine-big.png`, file exists, return file.

There are two things to be aware of here:

1. The deeper your path hierarchy, the more steps gridfs-fuse will take to find your file. Less directory nesting means faster file serving. The performance difference won't be massive, but it's there.
2. **/!\\ Big giant hack. /!\\** ***gridfs-fuse assumes that any path part with a period in it is the path leaf***. This is done so that we don't have to keep querying the DB with regexes, which degrades performance by about 90% in my testing. Always, always, always make sure your filenames have a period in them, and make sure your directories do not have a period in them. This is a rather hefty set of caveats, but if you'll stick to them, you will be rewarded with easy GridFS file serving.

<h3>What happens if I don't follow those rules?</h3>

A few things happen. If you put periods in directory names, you'll get 404s. They'll be fast 404s, but they'll be 404s. Even if a filepath is valid, like `/images/foo.bar/baz/bin.png`, gridfs-fuse will short-circuit at `images/foo.bar`, assuming that is the leaf of the hierarchy.

If you don't put a period in your filenames, then gridfs-fuse will keep returning "yup, that's a directory", even when your webserver requests `/images/foo.bar/baz/bin.png/index.html` and then `/images/foo.bar/baz/bin.png/index.html/index.html` and then `/images/foo.bar/baz/bin.png/index.html/index.html/index.html`, and so forth. There's a built-in stop at 10 levels deep - at 10 levels, gridfs-fuse gives up and just returns a 404, but it'll take you a relatively long time to get there, and it's really very highly recommended that you don't do that.

<h2>What about when gridfs-fuse isn't running?</h2>

Never fear, that's easily fixed. Just use a Rack or Rails Metal middleware to serve images from GridFS. This is <strong>massively</strong> slower than serving files through gridfs-fuse, but at least your visitors won't be treated to a site full of broken images if your mount point goes away for whatever reason. I'm using the following Metal endpoint. Just throw it into app/metals/gridfs.rb, add `config.metals = ["Gridfs"]` into your environment.rb, and you're off to the races.

~~~ruby
# rails metal to be used with carrierwave (gridfs) and MongoMapper

require 'mongo'
require 'mongo/gridfs'

# Allow the metal piece to run in isolation
require(File.dirname(__FILE__) + "/../../config/environment") unless defined?(Rails)

class Gridfs
  def self.call(env)
    if env["PATH_INFO"] =~ /^\/images\/gfs\/(.+)$/
      key = $1
      if ::GridFS::GridStore.exist?(MongoMapper.database, key)
        ::GridFS::GridStore.open(MongoMapper.database, key, 'r') do |file|
          [200, {'Content-Type' => file.content_type}, [file.read]]
        end
      else
        [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
      end
    else
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end
  end
end
~~~

(I didn't write that, but I can't find the source to give credit at the moment).

That gives you a highly performant front-end solution with a reliable fallback. For any given request, the following should happen:

1. Your webserver attempts to load the file out of GridFS. If it can't be found (likely due to a missing mountpoint), then...
1. The request will fall through to your Metal handler. It will then attempt to serve it from GridFS.
1. If it still can't be found, the request falls through to your Rails app.

To prevent step 3 from happening, you might want to change line 18 of the Metal handler to return a 200 and read out a generic "missing image" image of some sort. That'll prevent 404s from invoking a hit to your app.

Stick a CDN in front of it all, and you have a high-performance file upload solution with automatic replication and sharding that you can treat like any other piece of web data. Hooray!
