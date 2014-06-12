module Orchestrate::API

  # Base class for Errors from Orchestrate.
  class BaseError < StandardError
    # class-level attr-reader for the error's response code.
    # @return [Integer] Status code for error.
    def self.status; @status; end

    # class-level attr-reader for the error's code.
    # @return [String] API's error code.
    def self.code; @code; end

    # @return [Faraday::Response] The response that caused the error.
    attr_reader :response

    # @param response [Faraday::Response] The response that caused the error.
    def initialize(response)
      @response = response
      if response.headers['Content-Type'] == 'application/json'
        super(response.body['message'])
      else
        super(response.body)
      end
    end
  end

  # indicates a 4xx-class response, and the problem was with the request.
  class RequestError < BaseError; end

  # The client provided a malformed request.
  class BadRequest < RequestError
    @status = 400
    @code   = 'api_bad_request'
  end

  # The client provided a malformed search query.
  class MalformedSearch < RequestError
    @status = 400
    @code   = 'search_query_malformed'
  end

  # The client provided a ref value that is not valid.
  class MalformedRef < RequestError
    @status = 400
    @code   = 'item_ref_malformed'
  end

  # When a Search Parameter is recognized, but not valid.  For example, a limit
  # exceeding 100.
  class InvalidSearchParam < RequestError
    @status = 400
    @code   = 'search_param_invalid'
  end

  # A Valid API key was not provided.
  class Unauthorized < RequestError
    @status = 401
    @code   = 'security_unauthorized'
  end

  # Something the user expected to be there was not.
  class NotFound < RequestError
    @status = 404
    @code   = 'items_not_found'
  end

  # When a new collection is created by its first KV document, a schema is created
  # for indexing, including the types of the values for the KV document.  This error
  # will occur when a new document provides values with different types.  Values with
  # unexpected types will not be indexed.  Since search is an implicit feature
  # of the service, this is an error and worth raising an exception over.
  #
  # @example This is the example provided to me by the Orchestrate team:
  #   client.put(:test, :first, { "count" => 0 }) # establishes 'count' as a Long
  #   client.put(:test, :second, { "count" => "none" }) # 'count' is not a Long
  #
  class IndexingConflict < RequestError
    @status = 409
    @code   = 'indexing_conflict'
  end

  # Client provided a ref that is not the current ref.
  class VersionMismatch < RequestError
    @status = 412
    @code   = 'item_version_mismatch'
  end

  # Client provided "If-None-Match", but something matched.
  class AlreadyPresent < RequestError
    @status = 412
    @code   = 'item_already_present'
  end

  # indicates a 500-class response, the problem is on Orchestrate's end
  class ServiceError < BaseError; end

  class SecurityAuthentication < ServiceError
    @status = 500
    @code = 'security_authentication'
  end

  class SearchIndexNotFound < ServiceError
    @status = 500
    @code = 'search_index_not_found'
  end

  class InternalError < ServiceError
    @status = 500
    @code = 'internal_error'
  end

  # The full complement of Error classes.
  ERRORS=[ BadRequest, MalformedSearch, MalformedRef, InvalidSearchParam,
           Unauthorized, NotFound, IndexingConflict,
           VersionMismatch, AlreadyPresent,
           SecurityAuthentication, SearchIndexNotFound, InternalError
          ]

end
