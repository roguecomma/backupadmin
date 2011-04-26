Backupadmin::Application.routes.draw do

  devise_for :users, :controllers => { :registrations => "registrations" }

  root :to => 'servers#index'
  resources :servers do
    get :seed, :on => :member
  end
  resources :snapshots
  resources :snapshot_events
end
