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
        end
      end

      user.update!(attributes)

      if user.sign_in_count == 0
        if user.user_type == 'Staff'
          user.update_to_internal_price_group!
        end
      end


    end

  end

end
