module Orchestrate::API

  # Transforms the HTTParty response into a structure that provides ready
  # access to relevant orchestrate.io response data.
  #
  class Response
    # Header
    attr_reader :header

    # ResponseBody
    attr_reader :body

    # Creates Header and ResponseBody objects from the HTTParty response.
    # Let's Partay!
    #
    def initialize(partay)
      @success = partay.success?
      @header = Header.new partay.headers, partay.code, partay.msg
      @body = ResponseBody.new partay.body
    end

    # Returns the value of HTTParty.success?
    def success?
      @success
    end

    # Provides methods for ready access to relevant information extracted
    # from the HTTParty response headers.
    #
    class Header

      # Original response headers from HTTParty.
      attr_reader :content

      # HTTP response code.
      attr_reader :code

      # HTTP response status.
      attr_reader :status

      attr_reader :timestamp

      # ETag value, also known as the 'ref' value.
      attr_reader :etag

      # Link to the next url in a series of list requests.
      attr_reader :link

      def initialize(headers, code, msg)
        @content = headers
        @code, @status = code, msg
        @timestamp = headers['date']
        @etag = headers['etag'] if headers['etag']
        @link = headers['link'] if headers['link']
      end
    end
  end


  # Decodes body from json into a hash; provides the original body content
  # via the 'content' method.
  #
  class ResponseBody

    # Original response body from HTTParty.
    attr_reader :content

    # The json response body converted to a hash.
    attr_reader :to_hash

    # Set for all results.
    attr_reader :results

    # Set for list, search, get_events, and get_graph results.
    attr_reader :count

    # Set for search results.
    attr_reader :total_count

    # Set for list results.
    attr_reader :next

    # Error message from the orchestrate.io api.
    attr_reader :message

    # Error code from the orchestrate.io api.
    attr_reader :code

    # Initialize instance variables, based on response body contents.
    def initialize(body)
      @content = body
      @to_hash = (body.nil? || body == '' || body == {}) ? {} : JSON.parse(body)
      to_hash.each { |k,v| instance_variable_set "@#{k}", v }
    end

    def result_keys
      results.map { |result| result['path']['key'] } if results
    end
  end

end
