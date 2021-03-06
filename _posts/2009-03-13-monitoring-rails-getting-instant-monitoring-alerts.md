---
layout: post
title: 'Monitoring Rails: Getting instant monitoring alerts'
categories:
- Rails
- Ruby
tags:
- jabberish
- monitoring
- uptime
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '335112753'
---
Monitoring is big. Having an automated daemon watch your stuff and make sure it's running properly can let you sleep at night, knowing that if something blows up, there's an ever-watchful guardian ready to wake you up so you can fix it.

There are a number of monitoring solutions that are popular these days, such as <a href="http://mmonit.com/monit/">monit</a>, <a href="http://god.rubyforge.org/">god</a>, and <a href="http://www.nagios.org/">Nagios</a>. They're all fantastic, but sometimes you just want something simple and to-the-point, right?

With <a href="http://github.com/cheald/jabberish/tree/master/">jabberish</a> in your project, this becomes a no-brainer. I'm already using Jabberish in my project, so I whipped up a little script that checks system load, available memory, and any changes in swap usage and shoots me an IM under certain conditions. My monitoring still handles automated maintenance in the case of a runaway process or whatnot, but this keeps me instantly informed of any problems that my system might be running in to.

~~~ruby
require 'rubygems'
require 'drb'
require 'daemons'

MAX_MEMORY = 95
MAX_LOAD = 4.0
DELIVER_TO = "cheald@gmail.com"
JABBERISH_SERVER = "druby://localhost:35505"

$warned = {}
$hostname = `hostname`.strip

def im
	$im_service ||= DRbObject.new(nil, JABBERISH_SERVER)
end

def deliver(msg)
	im.deliver DELIVER_TO, "[#{$hostname}] #{msg}"
end

def check_stats
	meminfo = open("/proc/meminfo").read

	mtotal = meminfo.match(/MemTotal:\s+(\d+)/)[1].to_i
	mfree = meminfo.match(/MemFree:\s+(\d+)/)[1].to_i
	mused = mtotal - mfree

	stotal = meminfo.match(/SwapTotal:\s+(\d+)/)[1].to_i
	sfree = meminfo.match(/SwapFree:\s+(\d+)/)[1].to_i
	sused = stotal - sfree

	begin
		if $warned[:swap] and sused > $warned[:swap] then
			deliver "WARNING: Swap has increased from #{$warned[:swap]} to #{sused}"
		end
		$warned[:swap] = sused

		pct = mused / mtotal.to_f * 100.0
		if pct > MAX_MEMORY then
			unless $warned[:memory]
				deliver sprintf("ALERT: Memory free: %2.2fmb (%2.2f%% used)", mfree / 1024.0, pct)
				$warned[:memory] = true
			end
		else
			$warned[:memory] = false
		end

		load = open("/proc/loadavg").read.split(" ").first
		if load > MAX_LOAD then
			unless $warned[:load]
				deliver sprintf("WARNING: Load average is %s", load)
				$warned[:load] = true
			end
		else
			$warned[:load] = false
		end
	rescue
		puts "Error: #{$!}"
	end
end

Daemons.daemonize(:backtrace => true)

loop {
	check_stats
	sleep(10)
}
~~~

Not too bad, huh? This is written for a CentOS installation, so you may need to change things like the meminfo regexes depending on your system. It could probably use a YAML config file to be truly correct - configuration options in constants works, but is a little ugly.

Now I get alerts like these via instant message:

~~~ruby
[iceman.tagteam] WARNING: Load average is 4.44
[iceman.tagteam] ALERT: Memory free: 99.82mb (93.38% used)
[polaris.tagteam] ALERT: Memory free: 72.20mb (95.14% used)
~~~

This lets me respond to changing system conditions extremely rapidly, and serves as a high-level alert log when when I'm not at the keyboard - when I get back, I check my messages from blippr, and can see when and how often certain marginal conditions are being met.

Hope it's useful!
