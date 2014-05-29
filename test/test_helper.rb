require "orchestrate/api"
require "minitest/autorun"
require "json"
require "base64"
require "faraday"
require "securerandom"
require "time"

# Test Helpers ---------------------------------------------------------------

def output_message(name, msg = nil)
  msg ||= "START TEST"
  Orchestrate.config.logger.debug "\n======= #{msg}: #{name} ======="
end

# TODO this is a bit messy for now at least but there's a bunch of
# intermediate state we'd have to deal with in a bunch of other places
def make_client_and_artifacts
  api_key = SecureRandom.hex(24)
  basic_auth = "Basic #{Base64.encode64("#{api_key}:").gsub(/\n/,'')}"
  stubs = Faraday::Adapter::Test::Stubs.new
  # TODO: make it such that the client passes its optional config to the API::Request class
  Orchestrate.configure do |config|
    config.faraday = lambda do |faraday|
      faraday.adapter :test, stubs
    end
    config.api_key = api_key
    config.logger = Logger.new(File.join(File.dirname(__FILE__), "test.log"))
  end
  client = Orchestrate::Client.new
  [client, stubs, basic_auth]
end

def capture_warnings
  old, $stderr = $stderr, StringIO.new
  begin
    yield
    $stderr.string
  ensure
    $stderr = old
  end
end

def response_headers(specified={})
  {
    'Content-Type' => 'application/json',
    'X-Orchestrate-Req-Id' => SecureRandom.uuid,
    'Date' => Time.now.httpdate,
    'Connection' => 'keep-alive'
  }.merge(specified)
end

def chunked_encoding_header
  { 'transfer-encoding' => 'chunked' }
end

def response_not_found(items)
{ "message" => "The requested items could not be found.",
  "details" => {
    "items" => [ items ]
  },
  "code" => "items_not_found"
}.to_json
end

# Assertion Helpers

def assert_header(header, expected, env)
  assert_equal expected, env.request_headers[header]
end

def assert_authorization(expected, env)
  assert_header 'Authorization', expected, env
end

def assert_accepts_json(env)
  assert_match %r{application/json}, env.request_headers['Accept']
end


