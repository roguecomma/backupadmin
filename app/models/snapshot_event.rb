class SnapshotEvent < ActiveRecord::Base
  belongs_to :server

  before_save do
    self.created = Time.now unless self.created?
  end

  def self.log(server, event_type, log, exception = nil)
    event = SnapshotEvent.new
    event.server_id = server.id
    event.event_type = event_type
    event.log = log
    event.log = "#{event.log} - #{exception.message} - "+ (exception.backtrace.join("\n")).to_s if exception
    event.log = event.log[0, 65000] if event.log.length > 65000
    event.save!
  end
end
