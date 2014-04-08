module Orchestrate::API

  # Transforms the Net::HTTP response into a structure that provides ready
  # access to relevant orchestrate.io response data.
  #
  class Response
    # Header
    attr_reader :header

    # ResponseBody
    attr_reader :body

    def initialize(response)
      @success = [200, 201, 204].include? response.code.to_i
      @header  = Header.new(response.to_hash, response.code.to_i, response.message)
      @body    = ResponseBody.new(response.body)
    end

    # Returns boolean.
    def success?
      @success
    end

    # Provides methods for ready access to relevant information extracted
    # from the Net::HTTP response headers.
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
        @etag = get_etag
        @link = headers['link'] if headers['link']
      end

      private
        def get_etag
          if @code == 200 && @content['etag']
            @content['etag'].first.sub(/\-gzip/, '')
          elsif @code == 201 && @content['location'].present?
            "\"#{@content['location'].first.split('/').last}\""
          end
        end
    end
  end


  # Decodes body from json into a hash; provides the original body content
  # via the 'content' method.
  #
  class ResponseBody

    # Original response body from Net::HTTP.
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
