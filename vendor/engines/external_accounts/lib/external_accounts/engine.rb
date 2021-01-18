module ExternalAccounts

  class Engine < Rails::Engine

    config.to_prepare do
      #Rails.logger.info "prepare engine xxxxxxxxxxxxxxxxxxxxxxxxxxx"dddd
      ApplicationController.send :include, ExternalAccounts::ApplicationControllerExtension
      # disable payment source request page
      #NavTab::LinkCollection.send :include, ExternalAccounts::LinkCollectionExtension

    end

    initializer :append_migrations do |app|
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path
      end
    end
  end
end
