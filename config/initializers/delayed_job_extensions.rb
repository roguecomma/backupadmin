Delayed::Job.class_eval do
  after_create :invoke_non_deferred_task
  
  private 
    
    # Invoke job instead of saving to the db
    def invoke_non_deferred_task
      return if AppConfig.defer_background_tasks

      invoke_job

      self.destroy
    end
end
