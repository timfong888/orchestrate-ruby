module Orchestrate::API

	# Not used. But it does contain nice summary of orchestrate.io api errors.
  #
	module Error
		def errors
			@@errors ||= [
				{ :status => 400,
				  :code   => :api_bad_request,
				  :desc   => 'The API request is malformed.'
				},
				{ :status => 500,
				  :code   => :security_authentication,
				  :desc   => 'An error occurred while trying to authenticate.'
				},
				{ :status => 401,
				  :code   => :security_unauthorized,
				  :desc   => 'Valid credentials are required.'
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
				{ :status => 404,
				  :code   => :items_not_found,
				  :desc   => 'The requested items could not be found.'
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