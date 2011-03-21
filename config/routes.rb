Backupadmin::Application.routes.draw do
  root :to => 'servers#show'
  resources :servers
  resources :snapshots
  resources :snapshot_events
end
