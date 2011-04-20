class AddTagJob < Struct.new(:snapshot_id, :server_id, :key, :value)

  def initialize(snap_id, serv_id, k, v=nil)
    self.snapshot_id = snap_id
    self.server_id = serv_id
    self.key = k
    self.value = v
  end

  def perform
    server = Server.find(server_id)
    begin
      AWS.tags.create({:resource_id => snapshot_id, :key => key, :value => value}).tap do
        SnapshotEvent.log(server, 'add tag', "Snapshot (#{snapshot_id}), #{key} => #{value}")
      end
    rescue Fog::Service::NotFound => nf
      SnapshotEvent.log(server, 'add tag', "Failed: Snapshot (#{snapshot_id}) no longer exists. #{key} => #{value}")
    end
  end
end
