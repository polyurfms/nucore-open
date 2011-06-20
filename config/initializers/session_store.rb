# Be sure to restart your server when you modify this file.

NucoreOpen::Application.config.session_store :cookie_store, :key => '_nucore-open_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# NucoreOpen::Application.config.session_store :active_record_store

# middleware component for handling flash upload authenticity tokens
Rails.application.config.middleware.insert_before(Rails.application.config.session_store, FlashSessionCookieMiddleware, Rails.application.config.session_options[:key])