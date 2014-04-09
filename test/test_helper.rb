require "minitest/autorun"
require "json"
require "vcr"

require "orchestrate-api"

# Configure Orchestrate API Client -------------------------------------------

Orchestrate.configure do |config|
  config.api_key = ENV["TEST_API_KEY"]
  config.verbose = true
end

module Test
  def client
    @@client ||= Orchestrate::API::Wrapper.new
  end
end

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
  puts "\n======= #{msg}: #{name} ======="
end
