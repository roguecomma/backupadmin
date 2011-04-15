set :stages, %w(qa production)
require 'capistrano/ext/multistage'
require "bundler/capistrano"
require "whenever/capistrano"

set :application, "backupadmin"
set :repository,  "git@github.com:Viximo/backupadmin.git"
set :user, 'ubuntu'
set :deploy_to, "/var/www/#{application}"
set :deploy_via, :remote_cache
set :rails_env, lambda { stage.to_s }

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :whenever_roles, :cron
set :whenever_command, lambda { "bundle exec whenever" }
set :whenever_environment, lambda { rails_env }

set :bundle_without, [:test, :darwin]
set(:branch, tag) if exists?(:tag)

set :default_environment, lambda {{'RAILS_ENV' => rails_env}}

after 'deploy:finalize_update', 'db:symlink', 'amazon:symlink'
after 'deploy:update_code', 'deploy:migrate'

after 'deploy:start', 'services:start'
after 'deploy:stop', 'services:stop'
before 'deploy:restart', 'services:stop'
after 'deploy:restart', 'services:start'

namespace :amazon do
  task :symlink do
    run "ln -s #{shared_path}/amazon.yml #{release_path}/config/amazon_ec2.yml"
  end
end

namespace :db do
  task :symlink do
    run "rm #{release_path}/config/database.yml"
    run "ln -s #{shared_path}/database.yml #{release_path}/config/database.yml"
  end
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end

namespace :services do
  task :restart do
    sudo "monit restart -g {application}"
  end
  
  task :start do
    sudo "monit start -g #{application}"
  end
  
  task :stop do
    sudo "monit stop -g #{application}"
  end
end