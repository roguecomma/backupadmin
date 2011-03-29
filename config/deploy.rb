set :stages, %w(qa production)
require 'capistrano/ext/multistage'
require "whenever/capistrano"

set :application, "backupadmin"
set :repository,  "git@github.com:Viximo/backupadmin.git"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :whenever_roles, :cron
set(:branch, tag) if exists?(:tag)

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end