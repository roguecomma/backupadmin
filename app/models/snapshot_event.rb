class SnapshotEvent < ActiveRecord::Base
  belongs_to :server

  scope :join_server, includes(:server).order("#{self.table_name}.created_at DESC")

  def display_list(params)
  end

  def self.log(server, event_type, log, exception = nil)
    SnapshotEvent.create(:server => server, :event_type => event_type) do |event|
      event.log = log
      event.log = "#{event.log} - #{exception.message} - "+ (exception.backtrace.join("\n")).to_s if exception
    end
  end
end
