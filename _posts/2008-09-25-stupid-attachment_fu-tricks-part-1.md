---
layout: post
title: Stupid attachment_fu tricks, part 1
categories:
- Rails
- Ruby
tags:
- attachment_fu
- imagemagick
- Rails
- Ruby
status: publish
type: post
published: true
meta:
  _edit_last: '1'
  dsq_thread_id: '335200385'
---
<a href="http://svn.techno-weenie.net/projects/plugins/attachment_fu/">attachment_fu</a> is fantastic, but it's a bit limited for some purposes. Ever wanted to upload data from a URL instead of making people upload files? It's a common problem!

Presume that we have a model named Image, which is our target for attachment_fu. Adding URL upload capability is surprisingly simple:

~~~ ruby
class Image < ActiveRecord::Base

  # Standard attachment_fu inclusion here
  has_attachment :storage => :file_system,
    :content_type => :image,
    :resize_to => "1024x1024>",
    :path_prefix => "public/images/cache/attached",
    :format => "jpg"

  # Allows the direct assignment of a URL to this image,
  # which is the source image to save from
  def url=(v)
    self.uploaded_data = UrlUpload.new(v)
  end

  # Or, we can just pass a URL to Image#uploaded_data
  def uploaded_data=(url)
    if url.is_a? String and url.match /^http(s)?:\/\// then
      file = open(url)
      file.extend(UrlUpload)
      super(file)
    else
      super(url)
    end
  end
end

module UrlUpload
  def filename
    base_uri.to_s.split("/").last
  end

  def original_filename
    base_uri.to_s.split("/").last
  end
end
~~~

There you go. All you need now is `Image.create(:url => "http://some.url/to/an/image.png")` and when the model is saved, the image will be sucked down and saved. Easy!
