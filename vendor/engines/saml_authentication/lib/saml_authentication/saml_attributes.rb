# frozen_string_literal: true

module SamlAuthentication

  class SamlAttributes

    delegate :[], :except, to: :to_h
    @@cn = ""

    def initialize(saml_response)
      @saml_response = saml_response
    end

    def to_h
      @saml_response.attributes.resource_keys.each_with_object({}) do |key, memo|
        Rails.logger.info "#{key}:#{memo}"
        if key == "email"
         memo[key] = @@cn + "@polyu.edu.hk"
        elsif key == "username"
         @@cn = @saml_response.attribute_value_by_resource_key(key)
         Rails.logger.info "cn="+@@cn
        else
         memo[key] = @saml_response.attribute_value_by_resource_key(key)
        end
      end.with_indifferent_access
    end

    # Useful for debugging to see all the raw values we received
    def to_raw_h
      @saml_response.raw_response.attributes.to_h
    end

  end

end
