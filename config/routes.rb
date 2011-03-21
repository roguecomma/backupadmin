Backupadmin::Application.routes.draw do
  root :to => 'servers#index'
  resources :servers
  resources :snapshots
  resources :snapshot_events
end
