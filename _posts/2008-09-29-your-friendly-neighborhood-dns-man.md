---
layout: post
title: Your friendly neighborhood DNS man
categories: []
tags:
- dns
- domains
- mccain
- palin
- politics
- social media
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '335200436'
---
So there's been this gossipy story making the rounds on the social news sites, that the McCain camp has unbelievably registered <a href="http://voteforthemilf.com">voteforthemilf.com</a> and are redirecting it to their site! They've got traceroutes and everything! Oh! The sexism! Oh! The gall! Oh! The huge manatee!

Or, wait, no, maybe everyone running around screaming about this just doesn't have a clue as to what that really means.

To be perfectly clear, I write this without any intent to provide any political bias, but to explain a technical subtlety that is apparently lost on many people, and which therefore bears a need for some edumacation.

Domain names are like nicknames. They're for our convenience, since we remember <a href="http://google.com">google.com</a>, but we'd have a hard time remembering <a href="http://64.233.187.99">64.233.187.99</a> every time we wanted to search for something. However, we have to have systems in place that translate those nicknames into IP addresses. They're like phone numbers for computers. To place a call to someone, you would look up their name in a phone book, and then get their phone number, and then dial the phone number on your phone. This is, in effect, what DNS is - a giant phone book.

First, a few terms.

* DNS - Domain Name Server. A system that turns domain names into IP addresses. Think of it like your cell phone's phone book. You look up "Mom" and it knows which phone number you want to call.
* Top Level Domain Name Server - The servers that all computers get in contact with to find out which Authoritative Server holds the information they're looking for
* Authoritative Domain Name Server - The server that actually holds the IP address you're looking for.
</ul>

So, what happens when you type in a domain name?

1. Your computer issues a request to a top level DNS server, asking for the DNS server that holds information for that domain.
1. The DNS server you're pointed to says "Oh, I know what IP this domain belongs to, here's the IP address"
1. Your computer makes a connection to the IP address specified by the Authoritative DNS Server

Imagine this scenario, then. You need a phone number for your friend, Joe. You don't have it, but you know that Jenny, your socialite friend, would know someone who does. So, you call Jenny and say "Hey, do you know who has Joe's phone number?" Jenny gives you Jane's phone number. You then call Jane and say, "Hey, do you have Joe's phone number?" Jane does, and gives it to you. You can then call Joe directly. This is basically how a DNS lookup works.

Now, the trick here is that IP addresses don't get to decide what domain names point to them. So, I can register any domain name I want, and tell the DNS server responsible for that domain name that "Hey, this domain points to this IP address". Then, that DNS server will return that IP address any time someone asks what IP address that domain belongs to.

It's this subtlety that lets the above smear work. I can register any domain I want, and make it seamlessly redirect to any IP address I want. I could register `diggsucks.com` and point it to <a href="http://reddit.com">reddit.com</a>, and as far as anyone could tell, diggsucks.com would go to `reddit.com`.

To go back to the `voteforthemilf.com` issue, if I may return to the phone book analogy, this is as if I called up the phone company and said "Hey, my name is voteforthemilf.com and my phone number is 555-123-4567". They print it, and someone discovers it. They dial the number, and are connected to McCain campaign headquarters. The story here is that people immediately assume that because the phone number is that for the McCain campaign, it must have been the McCain campaign that put it there - a logical leap that is both bold and wrong.

For kicks, check out this domain that I've told my DNS server to redirect to John McCain's website:

    <a href="http://clearlymccain.coffeepowered.net">http://clearlymccain.coffeepowered.net</a>

This is a subdomain, obviously, but it's just as trivial to do it with any real domain.

And now you know how doman names work.
