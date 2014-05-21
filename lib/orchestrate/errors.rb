module Orchestrate

  # Not used. But it does contain nice summary of orchestrate.io api errors.
  #
  module Errors

    # given a response and a possible JSON response body, raises the
    # appropriate Exception
    def self.handle_response(response)
      error = ERRORS.find {|err| err[:status] == response.status }
      raise error[:class].new(error[:message], response)
    end

    # Base class for Errors when talking to the Orchestrate API.
    class Base < StandardError
      # The response that triggered the error.
      attr_reader :response

      def initialize(message, response)
        @resposne = response
        super(message)
      end
    end

    # indicates a 4xx-class response, and the problem was with the request.
    class RequestError < Base; end

    # A Valid API key was not provided.
    class Unauthorized < RequestError; end

    # Something the user expected to be there was not.
    class NotFound < RequestError; end

    ERRORS=[
      {status: 401, class: Unauthorized, message: 'Valid credentials are required.'},
      {status: 404, class: NotFound, message: 'The requested item could not be found.'}
    ]


    def self.errors
      @@errors ||= [
        { :status => 400,
          :code   => :api_bad_request,
          :desc   => 'The API request is malformed.'
        },
        { :status => 500,
          :code   => :security_authentication,
          :desc   => 'An error occurred while trying to authenticate.'
        },
        { :status => 400,
          :code   => :search_param_invalid,
          :desc   => 'A provided search query param is invalid.'
        },
        { :status => 500,
          :code   => :search_index_not_found,
          :desc   => 'Index could not be queried for this application.'
        },
        { :status => 500,
          :code   => :internal_error,
          :desc   => 'Internal Error.'
        },
        { :status => 412,
          :code   => :item_version_mismatch,
          :desc   => 'The version of the item does not match.'
        },
        { :status => 412,
          :code   => :item_already_present,
          :desc   => 'The item is already present.'
        },
        { :status => 400,
          :code   => :item_ref_malformed,
          :desc   => 'The provided Item Ref is malformed.'
        },
        { :status => 409,
          :code   => :indexing_conflict,
          :desc   => 'The item has been stored but conflicts were detected ' +
                     'when indexing. Conflicting fields have not been indexed.'
        },
    ]
    end
  end

end
