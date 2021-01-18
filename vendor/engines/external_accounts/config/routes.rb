Rails.application.routes.draw do
    resources :payment_source_requests, controller:"external_accounts/payment_source_requests", only: [:index] do
        member do
            get "sendMail", to:"external_accounts/payment_source_requests#sendMail" 
          end
    end
end
