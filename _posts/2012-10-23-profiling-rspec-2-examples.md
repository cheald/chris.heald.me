---
layout: post
title: Profiling RSpec 2 Examples
categories:
- Performance
- Rails
tags: []
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '896783395'
---
Tests can be slow. This is how to find out why they're slow.

Toss this bad boy into `spec/support/profile.rb` and tag any example with `:profile => true` and it'll spit out callgrind dumps for your consumption in <a href="http://kcachegrind.sourceforge.net/">KCachegrind</a> or similar.

If you specify `PROFILE=all` on your command line, it'll profile *all* examples, regardless of tagging. If you pass `PROFILE=true` (or any other non-nil, non-ALL value) then it'll profile tagged examples.

~~~ruby
RSpec.configure do |c|
  def profile
    result = RubyProf.profile { yield }
    name = example.metadata[:full_description].downcase.gsub(/[^a-z0-9_-]/, "-").gsub(/-+/, "-")
    printer = RubyProf::CallTreePrinter.new(result)
    open("tmp/performance/callgrind.#{name}.#{Time.now.to_i}.trace", "w") do |f|
      printer.print(f)
    end
  end

  c.around(:each) do |example|
    if ENV['PROFILE'] == 'all' or (example.metadata[:profile] and ENV['PROFILE'])
      profile { example.run }
    else
      example.run
    end
  end
end
~~~

Then add the tag to your tests:

~~~ruby
describe "A test" do
  it "can be profiled", :profile => true do
    expect { some_complex_operation }.to_not raise_error
  end
end
~~~

Bam.
