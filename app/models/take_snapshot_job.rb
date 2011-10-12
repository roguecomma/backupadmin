class TakeSnapshotJob < Struct.new(:frequency_bucket, :server_id, :queued_time)

  def initialize(bucket, a_server_id, time)
    self.frequency_bucket = bucket
    self.server_id = a_server_id
    self.queued_time = time
  end

  def perform
    server =  Server.find(server_id)
    server.snapshot_class.take_snapshot(server, frequency_bucket) unless SnapshotCreationJob.job_too_old_to_run(frequency_bucket, queued_time)
  end

  def reschedule_at(time_now, attempts)
    time_now + (attempts ** 4) + 30
  end
end
