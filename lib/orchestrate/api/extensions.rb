module Orchestrate::API

  # Implement the blank? helpers here, instead of requiring active_support/core_ext.
  class ::Object
    def blank?
      respond_to?(:empty?) ? empty? : !self
    end

    def present?
      !blank?
    end
  end

end
