---
layout: post
title: Rails Cookie Sessions and PHP
categories:
- Rails
- Ruby
tags:
- PHP
- yaml
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  _syntaxhighlighter_encoded: '1'
  dsq_thread_id: '395120802'
---
I recently found myself needing to share session data from my Rails app with a PHP app on the same domain. We use cookie sessions for a number of reasons, and while they work great, the data stored in them is stored in Ruby's native Marshal format, which is not trivial to reimplement in PHP. After trying to get the data unmarshaled for a bit, I had another idea - why not just change the storage format?

Fortunately, Ruby is deeply entangled with another more portable serialization format: YAML.

Rails manages its session cookies through the <a href="https://github.com/rails/rails/blob/2-3-stable/activesupport/lib/active_support/message_verifier.rb">MessageVerifier</a>. Easy enough - we can just write our own MessageVerifier that uses YAML rather than Marshal.

~~~ruby
module ActiveSupport
  class YamlMessageVerifier < MessageVerifier
    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      data, digest = signed_message.split("--")
      if data.present? &amp;&amp; digest.present? &amp;&amp; secure_compare(digest, generate_digest(data))
        str = ActiveSupport::Base64.decode64(data)
        if str[0..2] == '---'
          YAML::load str
        else # Handle old Marshal.dump'd session
          Marshal.load(str)
        end
      else
        raise InvalidSignature
      end
    end

    def generate(value)
      data = ActiveSupport::Base64.encode64s(YAML::dump value)
      "#{data}--#{generate_digest(data)}"
    end
  end
end
~~~

You'll notice that verify() can accept a Marshaled session as well; this lets you transparently transition existing cookies to the new format without any kind of session breakage. Nice.

Now, to use the verifier, we monkeypatch CookieStore:

~~~ruby
module ActionController
  module Session
    class CookieStore
      def verifier_for(secret, digest)
        key = secret.respond_to?(:call) ? secret.call : secret
        ActiveSupport::YamlMessageVerifier.new(key, digest)
      end
    end
  end
end
~~~

Now, this will work...at least at first glance, until you try to use the flash. This is a particularly nasty little problem, and it stems from the fact that Ruby's YAML implementation serializes Hash objects without their instance variables, and <a href="https://github.com/rails/rails/blob/2-3-stable/actionpack/lib/action_controller/flash.rb">FlashHash</a> inherits from Hash, and thus inherits its serialization/deserialization strategy. I worked for a while to monkeypatch those strategies, but I didn't like the result, and it felt a little hacky. Instead, I just took advantage of the YAML load lifecycle to make sure the FlashHash initializes properly:

~~~ruby
module ActionController
  module Flash
    class FlashHash
      def update_with_initializer(h)
        @used ||= {}
        update_without_initializer(h)
      end
      alias_method_chain :update, :initializer
    end
  end
end
~~~

The core problem is that `YAML::load` calls `Hash#update`, and `FlashHash` presumes that the `@used` instance variable is present and initialized to an empty hash. To fix that, I just aliased in an initializer to make sure that variable is set.

Note that if you are storing other Hash subclasses with instance variables that rely on those variables being persisted across sessions, they will break. However, you should only be storing primitive/array/hash data in the session if possible. FlashHash is sort of a nasty violation of this principle.

At this point, your session should be serializing to and from YAML. We'll want to read it from PHP, naturally. I'm using <a href="http://code.google.com/p/spyc/">SPYC</a> in the PHP project, which gets us Close Enough&trade;. It doesn't handle symbol keys, but we'll handle those in the PHP itself.

<h2>Reading from PHP</h2>

Reading the data back out is surprisingly simple. We have to verify the authenticity of the data, of course, by checking the hash, but then you just base64 decode the data, load it with spyc, and perform some simple transformation to turn symbols into strings. If you wanted to make it even easier, you could monkeypatch the cookie store to call `#stringify_keys!` on your session hash before serializing it (and then call `#with_indifferent_access` on the hash when you deserialize it. Be aware of the speed impact of such a decision before you do it.)

~~~php
function explode_symbols($arr) {
  $result = array();
  foreach($arr as $key => $val) {
    if(is_numeric($key) &amp;&amp; $val[0] == ":") {
      $bits = explode(":", $val, 3);
      $result[trim($bits[1])] = trim($bits[2]);
    } elseif (is_array($val)) {
      $result[$key] = explode_symbols($val);
    } else {
      $result[$key] = $val;
    }
  }    
  return $result;
}

function deserialize_session($session_key, $secret) {
  list($session64, $hash) = explode("--", $_COOKIE[$session_key], 2);
  if(hash_hmac("SHA1", $session64, $secret) == $hash) {
    $session = base64_decode($session64);
    return explode_symbols(spyc_load($session));
  } else {
    throw new Exception("Invalid session signature");
  }
}

$rails_session = deserialize_session("your_session_cookie_name", $your_session_cookie_secret);
~~~

<h2>Caveats</h2>

* Be aware that YAML is slower than Marshal
* Be aware that storing Hash subclasses in the session is likely going to Not Work.

And that's all there is to it. You can now share data between the two apps via the session cookie.
