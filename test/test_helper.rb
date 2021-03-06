require "orchestrate/api"
require "minitest/autorun"
require "json"
require "base64"
require "faraday"
require "securerandom"
require "time"
require "logger"

class ParallelTest < Faraday::Adapter::Test
  self.supports_parallel = true
  extend Faraday::Adapter::Parallelism

  class Manager
    def initialize
      @queue = []
    end

    def queue(env)
      @queue.push(env)
    end

    def run
      @queue.each {|env| env[:response].finish(env) unless env[:response].finished? }
    end
  end

  def self.setup_parallel_manager(options={})
    @mgr ||= Manager.new
  end

  def call(env)
    super(env)
    env[:parallel_manager].queue(env) if env[:parallel_manager]
    env[:response]
  end
end

Faraday::Adapter.register_middleware :parallel_test => :ParallelTest

# Test Helpers ---------------------------------------------------------------

def output_message(name, msg = nil)
  msg ||= "START TEST"
end

# TODO this is a bit messy for now at least but there's a bunch of
# intermediate state we'd have to deal with in a bunch of other places
def make_client_and_artifacts(parallel=false)
  api_key = SecureRandom.hex(24)
  basic_auth = "Basic #{Base64.encode64("#{api_key}:").gsub(/\n/,'')}"
  stubs = Faraday::Adapter::Test::Stubs.new
  client = Orchestrate::Client.new(api_key) do |f|
    if parallel
      f.adapter :parallel_test, stubs
    else
      f.adapter :test, stubs
    end
    f.response :logger, Logger.new(File.join(File.dirname(__FILE__), "test.log"))
  end
  [client, stubs, basic_auth]
end

def ref_headers(coll, key, ref)
  {'Etag' => %|"#{ref}"|, 'Location' => "/v0/#{coll}/#{key}/refs/#{ref}"}
end

def make_application(opts={})
  client, stubs = make_client_and_artifacts(opts[:parallel])
  stubs.head("/v0") { [200, response_headers, ''] }
  app = Orchestrate::Application.new(client)
  [app, stubs]
end

def make_ref
  SecureRandom.hex(16)
end

def make_kv_item(collection, stubs, opts={})
  key = opts[:key] || 'hello'
  ref = opts[:ref] || "12345"
  body = opts[:body] || {"hello" => "world"}
  res_headers = response_headers({
    'Etag' => "\"#{ref}\"",
    'Content-Location' => "/v0/#{collection.name}/#{key}/refs/#{ref}"
  })
  stubs.get("/v0/items/#{key}") { [200, res_headers, body.to_json] }
  kv = Orchestrate::KeyValue.load(collection, key)
  kv.instance_variable_set(:@last_request_time, opts[:loaded]) if opts[:loaded]
  kv
end

def make_kv_listing(collection, opts={})
  key = opts[:key] || "item-#{rand(1_000_000)}"
  ref = opts[:ref] || make_ref
  reftime = opts.fetch(:reftime, Time.now.to_f - (rand(24) * 3600_000))
  score = opts[:score]
  body = opts[:body] || {"key" => key}
  collection = collection.name if collection.kind_of?(Orchestrate::Collection)
  result = { "path" => { "collection" => collection, "key" => key, "ref" => ref }}
  if opts[:tombstone]
    result["path"]["tombstone"] = true
  else
    result["value"] = opts.fetch(:value, true) ? body : {}
  end
  result["reftime"] = reftime if reftime
  result["score"] = score if score
  result
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

def error_response(error, etc={})
  headers = response_headers(etc.fetch(:headers, {}))
  case error
  when :bad_request
    [400, headers, {message: "The API request is malformed.", code: "api_bad_request"}.to_json ]
  when :search_query_malformed
    [ 400, headers, {
      message: "The search query provided is invalid.",
      code: "search_query_malformed"
    }.to_json ]
  when :invalid_search_param
    [ 400, headers, {
      message: "A provided search query param is invalid.",
      details: { query: "Query is empty." },
      code: "search_param_invalid"
    }.to_json ]
  when :malformed_ref
    [ 400, headers, {
      message: "The provided Item Ref is malformed.",
      details: { ref: "blerg" },
      code: "item_ref_malformed"
    }.to_json ]
  when :unauthorized
    [ 401, headers, {
      "message" => "Valid credentials are required.",
      "code" => "security_unauthorized"
    }.to_json ]
  when :indexing_conflict
    [409, headers, {
      message: "The item has been stored but conflicts were detected when indexing. Conflicting fields have not been indexed.",
      details: {
        conflicts: { name: { type: "string", expected: "long" } },
        conflicts_uri: etc[:conflicts_uri]
      },
      code: "indexing_conflict"
    }.to_json ]
  when :version_mismatch
    [412, headers, {
      message: "The version of the item does not match.",
      code: "item_version_mismatch"
    }.to_json]
  when :already_present
    [ 412, headers, {
      message: "The item is already present.",
      code: "item_already_present"
    }.to_json ]
  when :service_error
    headers.delete("Content-Type")
    [ 500, headers, '' ]
  else raise ArgumentError.new("unknown error #{error}")
  end
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


