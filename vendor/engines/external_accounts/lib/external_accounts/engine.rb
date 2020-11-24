module ExternalAccounts

  class Engine < Rails::Engine

    config.to_prepare do
      #Rails.logger.info "prepare engine xxxxxxxxxxxxxxxxxxxxxxxxxxx"
      ApplicationController.send :include, ExternalAccounts::ApplicationControllerExtension

    end

    initializer :append_migrations do |app|
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path
      end
    end
  end
end
