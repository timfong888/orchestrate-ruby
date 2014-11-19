Orchestrate API for Ruby
========================
[![Build Status](https://travis-ci.org/orchestrate-io/orchestrate-ruby.png?branch=master)](https://travis-ci.org/orchestrate-io/orchestrate-ruby)

Ruby client interface for the [Orchestrate.io](http://orchestrate.io) REST API.

[rDoc Documentation](http://rdoc.info/gems/orchestrate/frames)

## Getting Started

The Orchestrate Gem provides two interfaces currently, the _method_ client and the _object_ client.  The method client is a solid but basic interface that provides a single entry point to an Orchestrate Application.  The object client uses the method client under the hood, and maps Orchestrate's domain objects (Collections, KeyValues, etc) to Ruby classes, and is still very much in progress.  This guide will show you how to use both.

### Object client use

#### Setup the Application and a Collection
```ruby
app = Orchestrate::Application.new(api_key)
users = app[:users]
```

#### Changing Data centers

By default, the host data center is AWS US East (https://api.orchestrate.io). To use another data center, such as AWS EU West, then you must initialize the client with the host URL http://api.aws-eu-west-1.orchestrate.io/.

```ruby
host = "https://api.aws-eu-west-1.orchestrate.io/"
app = Orchestrate::Application.new(api_key, host)
```

#### Store some KeyValues, List them
```ruby
users[:joe] = { "name" => "Joe" }           # PUTs joe, returns the input, as per Ruby convention on #[]=
users.set(:jack, { "name" => "Jack" })      # PUTs jack, returns a KeyValue
users.create(:jill, { "name" => "Jill" })   # PUT-If-Absent jill, returns a KeyValue
users << { "name" => "Unknown" }            # POSTs the body, returns a KeyValue
users.map {|user| [user.key, user.ref]}     # enumerates over ALL items in collection
```

#### Manipulate KeyValues
```ruby
jill = users[:jill]
jill[:name]                                 # "Jill"
jill[:location] = "On the Hill"
jill.value                                  # { "name" => "Jill", "location" => "On the Hill" }
jill.save                                   # PUT-If-Match, updates ref
```

#### Searching, Sorting for KeyValues
```ruby
users.search("name:Jill")                    # returns users with name "Jill"
users.search("name:Jill").order(:created_at) # returns users with name "Jill" in ascending order
```

The `order` method accepts multiple arguments, allowing you to sort search results based multiple parameters. When providing multiple field names to sort by each even-numbered argument must be either `:asc` or `:desc`.

```ruby
users.search("location: Portland").order(:name, :asc, :rank, :desc)
```

By default, odd-numbered arguments will be sorted in ascending order.
```ruby
users.search("location: Portland").order(:name) # returns users in ascending order by name
users.search("location: Portland").order(:name, :asc, :rank, :desc, :created_at) # :created_at argument defaults to :asc
```

### Method Client use

#### Create a Client
``` ruby
# method client
client = Orchestrate::Client.new(api_key)

# EU data center
host = "https://api.aws-eu-west-1.orchestrate.io/"
client = Orchestrate::Client.new(api_key, host)
```

#### Query Collections, Keys and Values
``` ruby
# method client
client.put(:users, :jane, {"name"=>"Jane"}) # PUTs jane, returns API::ItemResponse
jack = client.get(:users, :jack)            # GETs jack, returns API::ItemResponse
client.delete(:users, :jack, jack.ref)      # DELETE-If-Match, returns API::Response
client.list(:users)                         # LIST users, returns API::CollectionResposne
```

#### Search Collections
```ruby
client.search(:users, "location:Portland") # search 'users' collection for items with a location of 'Portland'
```

#### Sorting Collections
```ruby
client.search(:users, "location:Portland", { sort: "value.name:desc" }) # returns items sorted by a field name in descending order
client.search(:users, "location:Portland", { sort: "value.name:asc" }) # returns items sorted by a field name in ascending order
client.search(:users, "location:Portland", { sort: "value.name.last:asc,value.name.first:asc" }) # returns items sorted primarily by last name, but whenever two users have an identical last name, the results will be sorted by first name as well.
```

### Examples and Documentation

There are more examples at [Orchestrate's API Documentation][apidoc] and documentation in the [rdoc][].

[apidoc]: http://orchestrate.io/api/version

## Swapping out the HTTP back end

This gem uses [Faraday][] for its HTTP needs -- and Faraday allows you to change the underlying HTTP client used.  The Orchestrate client defaults to [net-http-persistent][nhp] for speed on repeat requests without having to resort to a compiled library.  You can easily swap in [Typhoeus][] which uses libcurl to enable fast, parallel requests, or [EventMachine HTTP][em-http] to use a non-blocking, callback-based interface.  Examples are below.

You may use Faraday's `test` adapter to stub out calls to the Orchestrate API in your tests.  See `tests/test_helper.rb` and the tests in `tests/orchestrate/api/*_test.rb` for examples.

[Faraday]: https://github.com/lostisland/faraday/
[nhp]: http://docs.seattlerb.org/net-http-persistent/
[Typhoeus]: https://github.com/typhoeus/typhoeus#readme
[em-http]: https://github.com/igrigorik/em-http-request#readme

### Parallel HTTP requests

If you're using a Faraday back end that enables parallelization, such as Typhoeus, EM-HTTP-Request, or EM-Synchrony you can use `Orchestrate::Client#in_parallel` to fire off multiple requests at once.  If your Faraday back end does not support this, the method will still work as expected, but Faraday will output a warning to STDERR and the requests will be performed in series.

Note that these parallel modes are not thread-safe.  If you are using the client in a threaded environment, you should use `#dup` on your `Orchestrate::Client` or `Orchestrate::Application` to create per-thread instances.

#### method client
``` ruby
client = Orchestrate::Client.new(api_key) {|f| f.adapter :typhoeus }

responses = client.in_parallel do |r|
  r[:list] = client.list(:my_collection)
  r[:user] = client.get(:users, current_user_id)
  r[:user_events] = client.list_events(:users, current_user_id, :notices)
end
# will return when all requests have completed

responses[:user] = #<Orchestrate::API::ItemResponse:0x00...>
```

#### object client
```ruby
app = Orchestrate::Application.new(api_key) {|f| f.adapter :typhoeus }

app.in_parallel do
  @items = app[:my_collection].each
  @user = app[:users][current_user_id]
end
@items.take(5)
```

Note that values are not available inside of the `in_parallel` block.  The `r[:list]` or `@items` objects are placeholders for their future values and will be available after the `in_parallel` block returns.  Since `take` and other enumerable methods normally attempt to access the value when called, you **must** convert the `app[:my_collection]` to an `Enumerator` with `#each` and access them outside the parallel block.

You can, inside the parallel block, construct further iteration over your collection with `Enumerable#lazy` like so:

```ruby
app.in_parallel do
  @items = app[:my_collection].each.lazy.take(5)
  ...
end
@items.force
```

Attempting to access the values inside the parallel block will raise an `Orchestrate::ResultsNotReady` exception.

Lazy enumerators are not available by default in Ruby 1.9.  Lazy enumerator results are not pre-fetched from orchestrate unless they are taken inside an `#in_parallel` block, otherwise results are fetched when needed.

### Using with Typhoeus

Typhoeus is backed by libcurl and enables parallelization.

``` ruby
require 'orchestrate'
require 'typhoeus/adapters/faraday'

client = Orchestrate::Client.new(api_key) do |conn|
  conn.adapter :typhoeus
end
```

### Using with EM-HTTP-Request

EM-HTTP-Request is an HTTP client for Event Machine.  It enables callback support and parallelization.


``` ruby
require 'em-http-request'

client = Orchestrate::Client.new(api_key) do |conn|
  conn.adapter :em_http
end
```

### Using with EM-Synchrony

EM-Synchrony is a collection of utility classes for EventMachine to help untangle evented code.  It enables parallelization.

``` ruby
require 'em-synchrony'

client = Orchestrate::Client.new(api_key) do |conn|
  conn.adapter = f.adapter :em_synchrony
end
```

## Release Notes

### November 19, 2014: release 0.9.2
  - Implement `SearchResults#order`, allowing `Collection` object results to be sorted.
  - Implement Data Center choice on `Orchestrate::Client` and `Orchestrate::Application`.

### October 8, 2014: release 0.9.1
  - Improvements to documentation.

### September 1, 2014: release 0.9.0
  - Implement `KeyValue#events`, `EventList` and `Events` to access events associated with a KeyValue.
  - Removed `KeyValue#loaded` attr reader, it pointed to an instance variable no longer in use.  Use `#loaded?` instead.

### August 6, 2014: release 0.8.1
  - Implement `KeyValue#refs`, `RefList` and `Ref` to access a KeyValue's Refs.
  - Refactor `Client` api accessors on Object client to internal `#perform` methods.

### July 24, 2014: release 0.8.0
  - **BACKWARDS-INCOMPATIBLE** Fix #69, `Client` will url-escape path segments.  If you have keys with slashes or spaces or other
    characters escaped by `URI.escape` the client will now behave as expected, however if you've used these keys with this client
    before you may not be able to get to those old keys.
  - Fix #78, KeyValues are given an empty hash value by default, instead of nil.
  - Change default value for `KeyValue#ref` to be false.  On save, this will send an `If-None-Match` header instead of omitting the condition.
  - Revisited `#in_parallel` methods, improved documentation, tests for Enumerables on Object client, made sure behavior conforms.
  - Implement `KeyValue#update` and `#update!` to update the value and save in one go.
  - Implement `Collection#stub` to instantiate a KeyValue without loading it, for access to Relations, Refs, Events, etc.
  - Implement `Collection#build` to provide a factory for unsaved KV items in a collection.
  - Implement `KeyValue#relation` for Graph / Relation queries on object client.
  - Implement `Collection#search` for Lucene queries on Collections via the object client.

### July 1, 2014: release 0.7.0
  - Fix #66 to make parallel mode work properly
  - Switch the default Faraday adapter to the `net-http-persistent` gem, which in casual testing yields much better performance for sustained use.
  - Introduced the object client, `Orchestrate::Application`, `Orchestrate::Collection` & `Orchestrate::KeyValue`

### June 24, 2014: release 0.6.3
  - Fix #55 to handle ping responses when unauthorized

### June 24, 2014: release 0.6.2
  - Fix #48 to remove trailing -gzip from Etag header for ref value.
  - Custom `#to_s` and `#inspect` methods for Client, Response classes.
  - Implement `If-Match` header for Client#purge
  - Implement Client#post for auto-generated keys endpoint

### June 17, 2014: release 0.6.1
  - Fix #43 for If-None-Match on Client#put
  - Fix #46 for Client#ping
  - License changed to ASLv2

### June 16, 2014: release 0.6.0
  - **BACKWARDS-INCOMPATIBLE** Reworked Client constructor to take API key and
    optional Faraday configuration block.  See 9045ffc for details.
  - Migrated documentation to YARD
  - Provide basic response wrappers specific to generic request types.
  - Raise Exceptions on error response from Orchestrate API.
  - Remove custom logger in favor of the option to use Faraday middleware.
  - Accept Time/Date objects for Timestamp arguments to Event-related methods.

### May 29, 2014: release 0.5.1
  - Fix problem with legacy code preventing gem from loading in some environments

### May 21, 2014: release 0.5.0
  Initial Port from @jimcar
  - Uses Faraday HTTP Library as backend, with examples of alternate adapters
  - Cleanup client method signatures
