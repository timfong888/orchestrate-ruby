require "orchestrate/api"
require "minitest/autorun"
require "json"
require "vcr"
require "faraday"
require "securerandom"
require "time"

# Configure VCR --------------------------------------------------------------

VCR.configure do |c|
  # c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
  c.cassette_library_dir = File.join(File.dirname(__FILE__), "fixtures", "vcr_cassettes")
  default_cassette_options = { :record => :all }
end

# Test Helpers ---------------------------------------------------------------

def output_message(name, msg = nil)
  msg = "START TEST" if msg.blank?
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
    config.faraday_adapter = [:test, stubs]
    config.api_key = api_key
    config.logger = Logger.new(File.join(File.dirname(__FILE__), "test.log"))
  end
  client = Orchestrate::Client.new
  [client, stubs, basic_auth]
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


