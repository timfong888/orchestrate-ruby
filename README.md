Orchestrate API for Ruby
========================
[![Build Status](https://travis-ci.org/orchestrate-io/orchestrate-ruby.png?branch=master)](https://travis-ci.org/orchestrate-io/orchestrate-ruby)

Ruby gem to provide an interface for the [Orchestrate.io](http://orchestrate.io) REST API.

Find the [docs here](http://jimcar.github.io/orchestrate/Orchestrate/API.html).

## Swapping out the HTTP backend

This gem uses [Faraday][] for its HTTP needs -- and Faraday allows you to change the underlying HTTP client used.  It defaults to `Net::HTTP` but if you wanted to use [Typhoeus][] or [EventMachine HTTP][em-http], doing so would be easy.

In your Orchestrate configuration, simply provide a `faraday` key with a block that will be called with the `Faraday::Connection` object.  You may decorate it with middleware or change the adapter as described in the Faraday README.  For example:

``` ruby
require 'faraday_middleware'     # required for instrumentation
Orchestrate.configure do |config|
  config.faraday = lambda do |faraday|
    faraday.adapter :em_http
    faraday.use :instrumentation
  end
end
```

You may use Faraday's `test` adapter to stub out calls to the Orchestrate API in your tests.  See `tests/test_helper.rb` and the tests in `tests/orchestrate/api/*_test.rb` for examples.

[Faraday]: https://github.com/lostisland/faraday/
[Typhoeus]: https://github.com/typhoeus/typhoeus#readme
[em-http]: https://github.com/igrigorik/em-http-request#readme

## Running the Tests

