class AddTagJob < Struct.new(:snapshot_id, :frequency_bucket, :server_id)

  def initialize(a_snapshot_id, bucket, a_server_id)
    self.snapshot_id = a_snapshot_id
    self.frequency_bucket = bucket
    self.server_id = a_server_id
  end

  def perform
    server = Server.find(server_id)
    AWS.tags.create({:resource_id => snapshot_id, :key => Snapshot.tag_name(frequency_bucket), :value => nil}).tap do
      SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{snapshot_id} add to bucket -> #{frequency_bucket}.")
    end
  end
end
