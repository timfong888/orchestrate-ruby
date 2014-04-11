require "orchestrate/api"
require "minitest/autorun"
require "json"
require "vcr"

# Configure Orchestrate API Client -------------------------------------------

Orchestrate.configure do |config|
  config.api_key = ENV["TEST_API_KEY"]
  config.logger = Logger.new(File.join(File.dirname(__FILE__), "test.log"))
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
  Orchestrate.config.logger.debug "\n======= #{msg}: #{name} ======="
end
