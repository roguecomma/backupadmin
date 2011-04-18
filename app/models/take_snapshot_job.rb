class TakeSnapshotJob < Struct.new(:frequency_bucket, :server_id, :queued_time)

  def initialize(bucket, a_server_id, time)
    self.frequency_bucket = bucket
    self.server_id = a_server_id
    self.queued_time = time
  end

  def perform
    Snapshot.take_snapshot(Server.find(server_id), frequency_bucket) unless SnapshotCreationJob.job_too_old_to_run(frequency_bucket, queued_time)
  end
end
