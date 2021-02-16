# frozen_string_literal: true

require "saml_authentication/saml_attributes"

module SamlAuthentication

  class UserUpdater

    def initialize(skip_attributes: [], **_args)
      @skip_attributes = Array(skip_attributes)
    end

    def call(user, saml_response, _auth_value)
      attributes = SamlAttributes.new(saml_response).except(*@skip_attributes).merge(
        encrypted_password: nil,
        password_salt: nil,
      )

      if Settings.uat.email.present?
        if user.email.present?
          attributes['email'] = user.email
        else
          attributes['email'] = attributes['username']+Settings.uat.email
        end
      end

      user.update!(attributes)
    end

  end

end
