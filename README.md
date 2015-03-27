Orchestrate API for Ruby
========================
[![Build Status](https://travis-ci.org/orchestrate-io/orchestrate-ruby.png?branch=master)](https://travis-ci.org/orchestrate-io/orchestrate-ruby)

Ruby client interface for the [Orchestrate.io](http://orchestrate.io) REST API.

[rDoc Documentation](http://rdoc.info/gems/orchestrate)

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

#### Manipulate KeyValues with PATCH
```ruby
jill.merge({location: "Under the Hill"})        # Updates jill by merging given partial value into existing value

# Patch Operations
jill.add('favorite_sibling', 'Jack').update     # adds new field/value pair to jill
jill.remove('favorite_sibling').update          # removes given field/value pair from jill
jill.replace('on_the_hill', false).update       # replaces given field with given value
jill.move('name', 'first_name').update          # moves given field's value to new field
jill.copy('first_name', 'full_name').update     # copies given field's value to another field
jill.increment('age', 1).update                 # increments given field (must have numeric value) by provided amount
jill.decrement('years_to_live', 1).update       # decrements given field (must have numeric value) by provided amount
jill.test('full_name', 'Jill').update           # tests equality of existing field/value pair with given field/value

# Patch Operations can be chained together to perform multiple updates to a KeyValue item
jill.add('favorite_food', 'Pizza').remove('years_to_live').update()
```

#### Searching, Sorting for KeyValues
```ruby
users.search("name:Jill").find                      # returns users with name "Jill"
users.search("name:Jill").order(:created_at).find   # returns users with name "Jill" in ascending order
```

The `order` method accepts multiple arguments, allowing you to sort search results based multiple parameters. When providing multiple field names to sort by each even-numbered argument must be either `:asc` or `:desc`.

```ruby
users.search("location: Portland").order(:name, :asc, :rank, :desc).find
```

By default, odd-numbered arguments will be sorted in ascending order.
```ruby
users.search("location: Portland").order(:name).find  # returns users in ascending order by name
users.search("location: Portland").order(:name, :asc, :rank, :desc, :created_at).find   # :created_at argument defaults to :asc
```

### Geo Queries
```ruby
# Create a Collection object
cafes = app[:cafes]

# Find cafes near a given geographic point
cafes.near(:location, 12.56, 19.443, 4, 'mi').find   # returns cafes in a 4 mile radius of given latitude, longitude

# Sort nearby cafes by distance
cafes.near(:location, 12.56, 19.443, 4, 'mi').order(:distance).find  # returns nearby cafes in ascending order (closest to farthest)

# Find cafes in a given area using a bounding box
cafes.in(:location, {north:12.5, east:57, south:12, west:56}).find   # returns all cafes within specified bounding box
```

### Aggregate Functions

```ruby
# Statistical Aggregate
products.search("*").aggregate  # Start the search query and aggregate param builder
  .stats("price")               # statistics on the price field for products matching the query
  .find                         # return SearchResults object to execute our query
  .each_aggregate               # return enumerator for iterating over each aggregate result

# Range Aggregate
products.search("*").aggregate  # Start the search query and aggregate param builder
  .range("num_sold")            # set field for range function
  .below(99)                    # count items with num_sold value below 99
  .between(1, 10)               # count items with num_sold value between 1 & 10
  .above(5)                     # count items with num_sold value above 5
  .find                         # return SearchResults object to execute our query
  .each_aggregate               # return enumerator for iterating over each aggregate result

# Distance Aggregate
cafes.near(:location, 12, 19, 4, 'mi').aggregate  # Start the near search query and aggregate param builder
  .distance("location")         # set field for distance function
  .below(3)                     # count cafes within 3 miles of given geographic point
  .between(3, 4)                # count cafes between 3 and 4 miles of given geographic point
  .above(1)                     # count cafes beyond 1 mile of given geographic point
  .find                         # return SearchResults object to execute our query
  .each_aggregate               # return enumerator for iterating over each aggregate result

# Time-Series Aggregate
# Accepted intervals are: year, quarter, month, week, day, and hour
comments.search("*").aggregate  # Start the near search query and aggregate param builder
  .time_series("posted", "day") # get count of comments posted by day
  .time_zone("+1100")           # set a specific time zone
  .find                         # return SearchResults object to execute our query
  .each_aggregate               # return enumerator for iterating over each aggregate result

# Multiple Aggregate Functions
products.search("*").aggregate  # Start the search query and aggregate param builder
  .stats("price")               # statistics on the price field for products matching the query
  .range("num_sold")            # set field for range function
  .below(99)                    # count items with num_sold value below 99
  .find                         # return SearchResults object to execute our query
  .each_aggregate               # return enumerator for iterating over each aggregate result
```

### Events
```ruby
steve = users['Steve']

# create new events
steve.events['wall_post'] << { text: "Hello!" }
steve.events['activities'] << { text: "first post" }

# search for events
users.search('first post').kinds('event').find

# search for 'wall_post' events
users.search('Hello').kinds('event').types('wall_post').find
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

#### Manipulate KeyValues with PATCH
```ruby
# Give a set of operations to manipulate a given key
# Operations are executed in sequential order
ops = [
  { "op" => "add", "path" => "nimble", "value" => true }, # adds new field/value pair
  { "op" => "remove", "path" => "nimble" }, # removes given field/value pair
  { "op" => "replace", "path" => "quick", "value" => true }, # replaces given field with given value
  { "op" => "move", "from" => "name", "path" => "first_name" }, # moves given field's value to new field
  { "op" => "copy", "from" => "city", "path" => "home_town" }, # copies given field's value to another field
  { "op" => "inc", "path" => "age", "value" => 1 }, # increment a numeric value at a given path
  { "op" => "inc", "path" => "age", "value" => -1 }, # pass a negative number to decrement a numeric value
  { "op" => "test", "path" => "first_name", "value" => "Jack" }, # tests equality of existing field/value pair with given field/value
]

client.patch(:users, :jack, ops)

# Merge partial values into existing key
client.patch_merge(:users, :jack, { favorite_food: "Donuts" })
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

### Geo Queries
```ruby
# Find cafes near a given geographic point

coords = {
  lat: 12.56,
  lon: 19.443,
  dist: '4mi' # Define size of search radius for NEAR query
}
query = "value.location:NEAR:{lat:#{coords.lat} lon:#{coords.lon} dist:#{coords.dist}}"
client.search(:cafes, query)    # returns cafes in a 4 mile radius of given latitude, longitude

# Using the previous coords & query,
# sort results by distance
client.search(:cafes, query, {
  sort: 'value.location:distance:asc'
})

# Find cafes in a given area using a bounding box
query = "value:IN:{ north:12.5 east:57 south:12 west:56 }"
client.search(:cafes, query)
```

### Aggregate Functions

```ruby
# Statistical Aggregate
query = "*"

options = {
  aggregate: "value.price:stats"    # get statistics for price across all items in the collection
}

response = client.search(:products, query, options)

response.aggregates     # return aggregate results


# Range Aggregate
query = "*"

options = {
  # count items with num_sold below 99, in between 1 & 10, and above 5
  aggregate: "value.num_sold:range:*~99:1~10:5~*"
}

response = client.search(:products, query, options)

response.aggregates     # return aggregate results


# Distance Aggregate
coords = {
  lat: 12.56,
  lon: 19.443,
  dist: '4mi' # Define size of search radius for NEAR query
}

options = {
  # count cafes near give geographic point within 3 miles, between 3 and 4 miles, and beyond 1 mile
  aggregate: "value.location:distance:*~3:3~4:1~*"
}

# Distance Aggregates require a near clause in the search query
query = "value.location:NEAR:{lat:#{coords.lat} lon:#{coords.lon} dist:#{coords.dist}}"

response = client.search(:cafes, query, options)

response.aggregates     # return aggregate results


# Time-Series Aggregate
# Accepted intervals are: year, quarter, month, week, day, and hour

options = {
  # get count of comments posted by day
  aggregate: "value.posted:time_series:day"
}

query = "*"

response = client.search(:comments, query, options)

response.aggregates     # return aggregate results


# Time-Series Aggregate with Time Zone

options = {
  # get count of comments posted by day
  aggregate: "value.posted:time_series:day:+1100"
}

query = "*"

response = client.search(:comments, query, options)

response.aggregates     # return aggregate results



# Multiple Aggregate Functions
options = {
  # multiple aggregate params are separated by commas
  aggregate: "value.price:stats,value.num_sold:stats,value.num_sold:range:*~99:1~10:5~*"
}

query = "*"

response = client.search(:products, query, options)

response.aggregates     # return aggregate results
```

### Examples and Documentation

There are more examples and documentation in [Orchestrate's API Documentation][apidoc] and the [rdoc][rdoc].

[apidoc]: http://orchestrate.io/api/version
[rdoc]: http://rdoc.info/gems/orchestrate

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

### March 27, 2015: release 0.11.2
  - Implement `Orchestrate::Search::QueryBuilder#kinds` to search events as well as KV items.
  - Implement `Orchestrate::Search::QueryBuilder#types` to search specific types of events.

### February 17, 2015: release 0.11.1
  - Implement `Search::TimeSeriesBuilder#time_zone` to designate time zone when calculating time series bucket boundaries.

### January 7, 2015: release 0.11.0
  - **BACKWARDS-INCOMPATIBLE** `Orchestrate::Collection` searches require `#find` method at the end of the method call/chain. Example: `users.search('foo').find`.
  - Implement `Orchestrate::Search` module, refactor functionality of prior `Orchestrate::Collection::SearchResults`.
  - Implement results enumeration & request firing functionality in prior `Orchestrate::Collection::SearchResults` to `Orchestrate::Search::Results`
  - Implement `Search::QueryBuilder` to construct `Collection` search queries.
  - Implement `Search::AggregateBuilder` to construct aggregate params on `Collection` search queries.
  - Implement `Search::StatsBuilder`, `Search::RangeBuilder`, `Search::DistanceBuilder`, & `Search::TimeSeriesBuilder` to construct aggregate function clauses for aggregate params.
  - Implement `Search::AggregateResult` objects to repesent aggregate results returned from `Collection` search.

### December 11, 2014: release 0.10.0
  - **BACKWARDS-INCOMPATIBLE** Prior `KeyValue#update` & `KeyValue#update!` renamed to `KeyValue#set` & `KeyValue#set!`. `KeyValue#update` now used after `PATCH` operations to fire the request.
  - Implement `Collection#near` & `Collection#in`, allowing `Collection` to perform geo queries.
  - Implement `Client#patch`, `Client#patch_merge`, allowing `Client` to perform partial updates through `PATCH` requests.
  - Implement `KeyValue::OperationSet`, allowing a set of `PATCH` operations to be built by `KeyValue` through `KeyValue#add`, `KeyValue#remove`, `KeyValue#replace`, `KeyValue#move`, `KeyValue#copy`, `KeyValue#increment`, `KeyValue#decrement`, & `KeyValue#test`. The `KeyValue::OperationSet` is fired by ending the chain with `KeyValue#update`.
  - Implement `KeyValue#merge`, allowing `KeyValue` to merge partial values into existing keys through `PATCH` requests.

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
