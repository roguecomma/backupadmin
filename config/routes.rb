Backupadmin::Application.routes.draw do

  devise_for :users, :controllers => { :registrations => "registrations" }

  root :to => 'servers#index'
  resources :servers
  resources :snapshots
  resources :snapshot_events
end
