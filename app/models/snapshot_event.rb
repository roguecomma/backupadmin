class SnapshotEvent < ActiveRecord::Base
  belongs_to :server

  scope :join_server, includes(:server).order("#{self.table_name}.created_at DESC")
  scope :for_server_id, lambda{|id| where(:server_id => id)}
  
  def display_list(params)
  end

  def self.log(server, event_type, log, exception = nil)
    SnapshotEvent.create(:server => server, :event_type => event_type, :log => log) do |event|
      if exception
        event.log = "#{event.log} - #{exception.message}\n#{exception.backtrace.join("\n")}" 
      end
      event.log = event.log.slice(0, 65534) if event.log.size >= 65535
    end
  end

  def self.clearout_old_events!
    # While the db may be gmtime and this query isn't, who really cares?
    delete_all(["#{table_name}.created_at < ?", 7.days.ago])
  end
end
