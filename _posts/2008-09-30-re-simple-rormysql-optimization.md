---
layout: post
title: 'Re: Simple RoR+MySQL optimization'
categories:
- Rails
- Ruby
tags:
- garabge collector
- mysql
- optimization
- orm
- Rails
- Ruby
status: publish
type: post
published: true
meta:
  _edit_last: '2'
  dsq_thread_id: '335553037'
---
I recently ran across a <a href="http://guruonrails.com/blog/simple-ror-mysql-optimization">rather bare post</a> espousing some generic "optimization" techniques for Rails apps. It offered no education, no explanation, no benchmarks. So, I thought, why not put those claims to the test?

## find\_by\_sql versus find\_by\_x

First, Konstantin claims that `Model#find_by_field` is slower than `Model#find_by_sql`. This one is hard to dispute; the first will invoke method_missing and spend time generating SQL, while the latter simply executes a statement. Is cutting the knees out from under your ORM worth the time saved? Let's see!

~~~ruby
require 'benchmark'

def measure_find_by_sql_vs_orm(num = 1000)
  puts "find_by_sql (#{num}x)"
  puts Benchmark.measure {
    num.times { User.find_by_sql "select * from users where id = 123" }
  }

  puts "find_by_id (#{num}x)"
  puts Benchmark.measure {
    num.times { User.find_by_id 123 }
  }
end

measure_find_by_sql_vs_orm(10000)
~~~

Let's run this a few times.

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    find_by_sql (10000x)
      2.290000   0.540000   2.830000 (  4.452150)
    find_by_id (10000x)
      4.660000   0.400000   5.060000 (  6.766629)

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    find_by_sql (10000x)
      2.300000   0.480000   2.780000 (  4.473950)
    find_by_id (10000x)
      4.520000   0.560000   5.080000 (  6.837272)

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    find_by_sql (10000x)
      2.170000   0.540000   2.710000 (  4.419207)
    find_by_id (10000x)
      4.580000   0.540000   5.120000 (  6.881676)

    find_by_sql: Averages 4.44 sec for 10,000 queries
    find_by_id: Averages 6.83 sec for 10,000 queries

Conclusion the first: Using the ORM to build SQL adds some overhead; in my tests, 2.47 sec/10,000 queries, or 0.000247 seconds per query. Is this worth optimizing out? Yeah, probably not. In fact, the productivity lost by using `find_by_sql` is likely going to end up costing the project more.

## IDs and numbers in quotes

Second, they claim that quoting values in your SQL statements slows down your queries. This one struck me as just a <em>little</em> out there. Let's see what the benchmarks say.

~~~ruby
require 'benchmark'

def measure_select_with_quotes(num = 1000)
  puts "Without quotes (#{num}x):"
  db = ActiveRecord::Base.connection.instance_variable_get :@connection
  puts Benchmark.measure {
    num.times { db.query("select * from users where id = 123") {} }
  }

  puts "With quotes (#{num}x):"
  puts Benchmark.measure {
    num.times { db.query("select * from users where id = \"123\"") {} }
  }
end

measure_select_with_quotes(10000)
~~~

And the results:

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    Without quotes (10000x):
      0.690000   0.340000   1.030000 (  2.639554)
    With quotes (10000x):
      0.670000   0.290000   0.960000 (  2.655049)

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    Without quotes (10000x):
      0.570000   0.320000   0.890000 (  2.654003)
    With quotes (10000x):
      0.550000   0.400000   0.950000 (  2.617369)

Well, that's certainly interesting. In 10,000 queries, an average difference of about 3/100ths of a second. Certainly not worth combing through your codebase as an optimization point.

Conclusion the second: The performance gain from quoted versus non-quoted field values is so small to be inconsequential.

On a side note, there is a <b>very</b> interesting subtlety here. Observe the difference between

~~~ruby
num.times { db.query("select * from users where id = 123") {} }
~~~

and

~~~ruby
num.times { db.query("select * from users where id = 123") }
~~~

The former passes the `Mysql::Result` object to a block, and frees it after the block terminates. The latter does not, and the returned `Mysql::Result` object remains in scope for the entire pass of the benchmark. This subtlety makes a massive difference.

~~~ruby
def measure_select_with_free(num = 1000)
  db = ActiveRecord::Base.connection.instance_variable_get :@connection

  puts "Query with block, result immediately freed"
  puts Benchmark.measure {
    num.times { db.query("select * from users where id = 123") {} }
  }

  puts "Query without block, result remains in scope"
  puts Benchmark.measure {
    num.times { db.query("select * from users where id = 123") }
  }
end
~~~

Results:

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    Query with block, result immediately freed
      0.060000   0.040000   0.100000 (  0.267983)
    Query without block, result remains in scope
      5.040000   0.050000   5.090000 (  5.266476)

Whoa damn. Ruby's GC is <i>slaughtering</i> performance there. Just adding a pair of curly braces makes the benchmark run <i>20 times faster</i>.

## It's better to request only specific column

Finally, Konstantin mentions that selecting only specific fields from a table is faster. This is a truth in both MySQL and in the ActiveRecord ORM, for a number of reasons. However, he says:

> Person.find\_by\_name("Name").phone\_number. It would be much faster if you use: Person.find\_by\_sql("SELECT persons.phone_number WHERE persons.name = 'Name'")

Why not just use the :select option that ActiveRecord provides?

~~~ruby
Person.find_by_name("Name", :select => "phone_number")
~~~

Let's test those assumptions.

~~~ruby
def measure_single_field_select(num = 1000)
  puts "Find with all fields"
  puts Benchmark.measure {
    num.times { User.find_by_id(123)}
  }

  puts "Find with one field, with :select"
  puts Benchmark.measure {
    num.times { User.find_by_id(123, :select => "email")}
  }
end
~~~

Results:

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    Find with all fields
      0.720000   0.060000   0.780000 (  0.963273)
    Find with one field, with :select
      0.310000   0.010000   0.320000 (  0.364554)

    [chris@polaris benchmarks]$ script/runner benchmark.rb
    Find with all fields
      0.710000   0.110000   0.820000 (  1.014548)
    Find with one field, with :select
      0.260000   0.020000   0.280000 (  0.351761)

Very significant difference there...and we didn't have to bypass the ORM to get it, either.
