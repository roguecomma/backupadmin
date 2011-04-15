class RemoveTagJob < Struct.new(:snapshot_id, :frequency_bucket, :server_id)

  def initialize(a_snapshot_id, bucket, a_server_id)
    self.snapshot_id = a_snapshot_id
    self.frequency_bucket = bucket
    self.server_id = a_server_id
  end

  def perform
    server = Server.find(server_id)
    AWS.delete_tags(snapshot_id, Snapshot.tag_name(frequency_bucket) => nil).tap do
      SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{snapshot_id} removed from bucket -> #{frequency_bucket}.")
    end
  end
end
