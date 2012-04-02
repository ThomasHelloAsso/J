WebClientV2::Application.routes.draw do
  root :to => "Dashboards#index"

  resource :registrations, :only => [:create]

  resources :authentications, :only => [:create, :notify_forgot_password] do
  end

  resource :profiles, :only => [:show, :update]

  resources :jots do
    get 'favorite'
    get 'thumbsup'
    get 'thumbsdown'

    resources :comments, :only => [:create, :index]
  end

  get '/auth/facebook', :as => 'login_with_facebook'
  get '/auth/facebook/callback' => 'authentications#facebook'
  get '/auth/twitter', :as => 'login_with_twitter'
  get '/auth/twitter/callback' => 'authentications#twitter'
  get '/auth/failure' => 'authentications#failure'
  get '/auth/facebook_connection', :as => 'facebook_connection'
  get '/auth/facebook_connection/callback' => 'authentications#facebook_connection'
  get '/auth/twitter_connection', :as => 'twitter_connection'
  get '/auth/twitter_connection/callback' => 'authentications#twitter_connection'

  post '/notify_forgot_password' => 'authentications#notify_forgot_password', :as => 'notify_forgot_password'
  post '/reset_forgot_password' => 'authentications#reset_forgot_password', :as => 'reset_forgot_password'

  resource :connections, :only => [] do
    get 'remove/:id' => 'connections#remove', :as => 'remove'
  end
end
