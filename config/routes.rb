Backupadmin::Application.routes.draw do
  ## Why doesn't this root thing work?
  root :to => 'servers#show'
  resources :servers
  resources :snapshot_events
end
