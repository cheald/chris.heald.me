---
layout: post
title: "Seppuqu: Self-terminating Sidekiqs"
categories:
- Sidekiq
tags:
- sidekiq
type: post
published: true
image:
  feature: 2013/08/seppuqu.png
---

We've been having an issue with Sidekiq occassionally not shutting down properly during a deployment. This ends up causing issues, since it can mean that we get Sidekiq workers that end up running different code than what we expect that they're running.

I whipped up a quick little middleware that causes Sidekiq to self-terminate if it determines that it's running a version of code that is older than the latest release. We use Capistrano, so my `Sidekiq::current_release_version` code just parses out the current version from the path, but you could use whatever versioning system you want as long as it compares `<` and `>` cleanly.

At some point I'll probably wrap this up into a little gem.

~~~ruby
# In an initializer
module Sidekiq
  def self.current_release_version
    @current_release_version ||= File.expand_path(__FILE__).scan(/\d{10,}/).map(&:to_i)[0] || -1
  end

  def self.latest_release_version
    Sidekiq.redis do |conn|
      conn.get("release_version") || -1
    end.to_i
  end

  module Middleware
    class VersionEnforcerMiddleware
      def call(worker, msg, queue)
        lrv, crv = Sidekiq.latest_release_version, Sidekiq.current_release_version
        if lrv <= crv
          yield
        elsif 
          Sidekiq.logger.info "My version (#{crv}) mismatches latest version (#{lrv}). Shutting down..."
          Thread.main.raise Interrupt
        end
      end      
    end
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::VersionEnforcerMiddleware
  end
end

Sidekiq.redis {|c| c.set "release_version", Sidekiq.current_release_version }  
~~~