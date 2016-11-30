---
layout: post
title: When you have to store user passwords...
categories:
- Rails
- Ruby
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '340947408'
---
Today we got word of yet-another-database-hack-with-plaintext-passwords. <a href="http://www.techcrunch.com/2009/12/14/rockyou-hack-security-myspace-facebook-passwords/">This time, it's RockYou</a>, purveyor of many of those Facebook and Myspace apps you use. Oops.

Every time this comes up, everyone says "How naive! They should have been using salted hashed passwords!" This is true in any case where you don't need to use the password again on an external service. With OAuth solutions becoming more and more popular, the need to collect and store user passwords is fortunately becoming more and more rare. However, it does need to happen sometimes, so how do you take the proper precautions when you do need to?

The first step is to encrypt your data before it is persisted into your database. This is pretty easy to do, and there are a number of methods for it. Here's an example of something I used in a Rails app to provide encryption services.

~~~ruby
require 'openssl'
require 'base64'
module Encryption
	class OpenSSL_Key
		PUBLIC_KEY_FILE = "#{RAILS_ROOT}/config/public.pem"
		PRIVATE_KEY_FILE = "#{RAILS_ROOT}/config/private.pem"

		def self.encrypt(data)
			@@public_key ||= OpenSSL::PKey::RSA.new(File.read(PUBLIC_KEY_FILE))
			encrypted_data = @@public_key.public_encrypt(data)
			Base64.encode64(encrypted_data)
		end

		def self.decrypt(data)
			@@private_key ||= OpenSSL::PKey::RSA.new(File.read(PRIVATE_KEY_FILE))
			decoded_data = Base64.decode64(data)
			@@private_key.private_decrypt(decoded_data)
		end
	end

	class OpenSSL_RSA
		IV64 = "xxxxxxxxxxxxxxxxxxxxxxxxxx==\n"
		KEY64 = "xxxxxxxxxxxxxxxxxxxxxxxxxx=\n"
		CIPHER = 'aes-256-cbc'

		def self.encrypt(data)
			@@iv ||= Base64.decode64(IV64)
			@@key ||= Base64.decode64(KEY64)

			cipher = OpenSSL::Cipher::Cipher.new(CIPHER)
			cipher.encrypt
			cipher.key = @@key
			cipher.iv = @@iv
			encrypted_data = cipher.update(data)
			encrypted_data << cipher.final
			Base64.encode64(encrypted_data)
		end

		def self.decrypt(data)
			@@iv ||= Base64.decode64(IV64)
			@@key ||= Base64.decode64(KEY64)

			cipher = OpenSSL::Cipher::Cipher.new(CIPHER)
			cipher.decrypt
			cipher.key = @@key
			cipher.iv = @@iv
			decrypted_data = cipher.update(Base64.decode64(data))
			decrypted_data << cipher.final
		end
	end
end
~~~

This provides two classes, `Encryption::OpenSSL_Key` and `Encryption::OpenSSL_RSA` which may be used to encrypt arbitrary strings. The OpenSSL_Key class uses a public/private keypair (in our example, read out of the Rails config directory), and the OpenSSL_RSA class uses an initialization vector and secret key. The latter is probably easier, since it means you don't have to worry about keypairs, and since all the encrypt/decrypt is done locally, there isn't any need for public public encryption.

Once you have that file in your project, using it is pretty simple.

~~~ruby
# Our databse is going to have a field called encrypted_password. We'll use attr_accessor for the password itself.

class MySecretModal < ActiveRecord::Base
	before_save :encrypt_fields
	attr_accessor :password

	def password
		@decrypted_password ||= decrypt_field(:password)
	end

private

	def encrypt_fields
		write_attribute :encrypted_password, Encryption::OpenSSL_RSA.encrypt(@password)
	end

	def decrypt_field(field)
		Encryption::OpenSSL_RSA.decrypt read_attribute("encrypted_#{field}")
	end
end
~~~

The net result is that we can still get access to the raw password if we need to, but the content in the database will be RSA-encrypted against a secret key in our application. This is still vulnerable if the attacker gains access to the file containing your RSA IV/key, or if he gains access to your public/private keypair, but it is extremely resilient in the case that an attacker manages to simply dump your users table via SQL injection. You still need to practice good key management, and you absolutely should not use a technique this simplistic for storing financial data - there are a whole set of guidelines and procedures for that kind of information. However, for adding an extra layer of defense to save yourself and your customers from excess embarrassment in the case of a database breach, this is a quick, easy, and effective technique for hardening your data.

This is a rather raw implementation, and there are ways you could package it up so that you could transparently apply it to any number of models or fields, but the basic technique is solid. You could even use something like <a href="http://github.com/Mechaferret/sql_crypt">sql_crypt</a> to easily protect sensitive fields. The technology is there, and "We needed to be able to re-use the password!" isn't an excuse anymore. Stop storing plaintext passwords - just like backups, it's just extra work until you need it, and then you'll be glad you put that extra work in.
