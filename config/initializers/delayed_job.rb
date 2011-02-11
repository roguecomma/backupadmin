Delayed::Worker.guess_backend
Delayed::Worker.destroy_failed_jobs = true

# Force the notification client class to load, or delayed notification jobs will fail 
# http://stackoverflow.com/questions/2569396/rails-delayed-job-library-class
#Notifications::Notification

Delayed::Worker.backend.class_eval do
  class << self
    def after_fork_with_rename
      after_fork_without_rename
      $0 = 'delayed_job backupadmin' # whatever the project name is
    end
    alias_method_chain :after_fork, :rename
  end
end