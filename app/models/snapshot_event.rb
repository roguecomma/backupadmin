class SnapshotEvent < ActiveRecord::Base
  before_save do
    created = Time.now unless created?
  end

  def self.log(server, event_type, log)
    event = SnapshotEvent.new
    event.server_id = server.id
    event.event_type = event_type
    event.log = log
    event.save!
  end
end
