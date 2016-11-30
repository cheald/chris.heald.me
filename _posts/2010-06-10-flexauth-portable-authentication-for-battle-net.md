---
layout: post
title: 'FlexAuth: Portable authentication for Battle.net'
categories: []
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '334983680'
---
I've just released my first Android app, called <a href="http://www.cyrket.com/p/android/com.chrisheald.flexauth/">FlexAuth</a>. It's mostly an excuse to learn Android development, but it does something useful, too - it serves as a souped-up mobile authenticator for Blizzard's Battle.net login infrastructure. If you'd like the gory details, <a href="http://bnetauth.freeportal.us/specification.html">there's a specification floating around on the internet</a> that'll help you understand the protocol.

<a href="http://i.imgur.com/yW496.png"><img src="http://i.imgur.com/yW496.png" align="right" style="margin: 1em; width:200px;" /></a>
Mobile authenticators work by transforming a seed value (called the "token secret") + the current time into your 8-digit authentication code. FlexAuth lets you set up multiple authenticators by providing the secret, or will let you have Blizzard generate one for you.

## Why would you need this?

* You want to use a mobile authenticator, but don't want to be locked out if you ever lose your phone (just setup a new token with your registered token secret).
* You want to use multiple mechanisms to log in - maybe you need token authentication in a script, or you want to have the same authenticator values on multiple mobile phones.
* You already have a token secret from another source and want to use it on your mobile phone.

Obviously, these won't apply to most people, but some folks will definitely find it useful.

<a href="http://i.imgur.com/NbAGQ.png"><img src="http://i.imgur.com/NbAGQ.png" align="right" style="margin: 1em; width:200px;" /></a>

## Using it

1. Menu -> Add Account
1. Enter a name for this token/account. It can be whatever you'd like.
1. Either enter a serial + secret, or you can use the already-provided one, or generate a new one.
1. Save the token. You'll notice that auth codes start generating right away.
1. It is highly recommended that you back up your token secret. If you uninstall the app, wipe your phone, etc, then you will lose the secret, and consequently lose the ability to generate auth codes. To back up a code, click into the token's details, and long press on the secret to copy it. You can then paste it into a note or email or whatnot. To restore a token, simply generate a new token and use your backed up secret. It will generate compatible auth codes.

All that said, <span style="color: #ff0000;">a word of caution</a>: <b>Never ever ever run authenticator software on the same machine that you're logging in on.</b> It's bad, it's dumb, and you shouldn't do it. Keep your authentication token generation on a separate device if you value your account.

If <a href="http://www.wowwiki.com/Battle.net_Mobile_Authenticator#Desktop_port">any particular same-machine authentication scheme</a> gained any measure of popularity, it would be targeted by malware and your authenticator would be useless. Don't do it.

Other than that, enjoy!
