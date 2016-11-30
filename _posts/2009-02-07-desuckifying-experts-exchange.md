---
layout: post
title: Desuckifying Experts-Exchange
categories: []
tags:
- firefox
- rip
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _oembed_f83fba6cf42ae18fb586a49d37cf107c: '{{unknown}}'
  dsq_thread_id: '335200478'
---

If you've ever searched for an answer to a programming problem, chances are good that you've run into results from experts-exchange. Everyone hates them. The information usually isn't that good, and even if it is, you have to scroll past sixteen pages of ads and spam to get to them. Unfortunately, there's the occasional nugget of info that's what you're looking for. There's just too much crap to dig through to get to it.

We're gonna fix that.

You'll need:

* Firefox
* <a href="https://addons.mozilla.org/en-US/firefox/addon/521">Remove it Permanently</a>
* The RIP export file below, saved as a file


~~~xml
<Config version="1.0">
	<Page name="Experts Exchange" url="http://*experts-exchange.com*" enabled="true">
		<XPath comment="">//div[@class='s sectionFour shFFF5 sgray expGray allZonesMain taSearchRow']</XPath>
		<XPath comment="">//div[@class='bl blQuestion']//div[@class='answers']</XPath>
		<XPath comment="">//a[@class='startFreeTrial']</XPath>
		<XPath comment="">//div[@id='relatedSolutions20X6']</XPath>
		<XPath comment="">//div[@id='compSignUpNowVQP32']</XPath>
	</Page>
</Config>
~~~

Go to your RIP options, click "Import Rip", and import that rip config. Presto chango, Experts-Exchange looks like a sane, readable website.

Enjoy.

Edit: It appears that Experts-Exchange only inlines answers for unregistered users if you have a search engine referral URL, obviously so they can saturate search results to bait-and-switch people into registering for the service without getting smacked for information cloaking. There's an easy answer, though.

1. Grab <a href="https://addons.mozilla.org/en-US/firefox/addon/953">https://addons.mozilla.org/en-US/firefox/addon/953</a>
2. Set your referrer for experts-exchange.com to
`http://www.google.com/search?q=woo+woo+woo+woo&ie=utf-8&oe=utf-8&aq=t&rls=org.mozilla:en-US:official&client=firefox-a`
3. Yay, information.
