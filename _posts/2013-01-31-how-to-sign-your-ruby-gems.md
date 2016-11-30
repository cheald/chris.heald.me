---
layout: post
title: How to sign your Ruby gems
categories:
- Ruby
- Security
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '1057441131'
---
In light of the recent <a href="http://news.ycombinator.com/item?id=5139583">Rubygems security issues</a>, I've been adding signatures to my own gems, and encouraging other gem authors to do the same by opening issues on various Github projects. Gem signing coupled with publication of a pubkey allows people to verify the authenticity of your published gems against your repository, so that they can be certain that the gems they are downloading from Rubygems (or where ever) are authentic and were actually released by you, the gem author (as opposed to, say, backdoored and uploaded to Rubygems by a malicious entity in the event of another security breach).

The how-to is here: <a href="http://docs.rubygems.org/read/chapter/21">http://docs.rubygems.org/read/chapter/21</a>

TL;DR:

1. `gem cert --build your@email.com`
1. Copy the private key somewhere safe (I use `~/.gemcert`)
1. Add the public key to the repo (`git add gem-public_cert.pem`)
1. Update the gemspec with something like:

    ~~~ruby
    s.signing_key = '/home/chris/.gemcert/gem-private_key.pem'
    s.cert_chain  = ['gem-public_cert.pem']
    ~~~

1. Push and rake release

While this does mean that your gem is signed by a self-signed certificate, and thus the lack of chain-of-trust means that your gem would not be verifiable if your Github credentials or machine housing your private key were compromised, it provides a layer of verification between source and package publication platforms, and would allow for much speedier community recovery in the event of a future breach.

This is quick, easy, and has no downside. I encourage all gem authors to immediately add signatures to their gems, and for all gem users to open or support issues on your favorite gem projects to encourage their maintainers to do the same.
