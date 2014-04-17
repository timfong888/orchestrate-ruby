Orchestrate API for Ruby
========================

Ruby gem to provide an interface for the [Orchestrate.io](http://orchestrate.io) REST API.

Find the [docs here](http://jimcar.github.io/orchestrate/Orchestrate/API.html).

## Running the Tests

The API client requires an API Key in the TEST_API_KEY environment variable,
and the test harness requires the same API that the tests were recorded with,
`TEST_API_KEY=0384407c-95e1-4b27-aa6f-c5a7cb685015`.  In bash, you can run
tests like so:

    TEST_API_KEY=0384407c-95e1-4b27-aa6f-c5a7cb685015 bundle exec rake test
