class SnapshotEvent < ActiveRecord::Base
  belongs_to :server

  scope :join_server, includes(:server).order("#{self.table_name}.created_at DESC")
  scope :for_server_id, lambda{|id| where(:server_id => id)}
  
  def display_list(params)
  end

  def self.log(server, event_type, log, exception = nil)
    SnapshotEvent.create(:server => server, :event_type => event_type) do |event|
      if exception
        log = "#{event.log} - #{exception.message}\n#{exception.backtrace.join("\n")}" 
        event.log = log.slice(0, 65534) if log.size >= 65535
      end
    end
  end
end
