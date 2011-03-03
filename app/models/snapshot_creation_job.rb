class SnapshotCreationJob < Struct.new(:frequency_bucket)

  def initialize(bucket, time=Time.now)
    @frequency_bucket = bucket
    @queued_time = time
  end

  def perform
    if job_too_old_to_run(@frequency_bucket, @queued_time)
      custom_notify('DJ Slow', "SnapshotCreationJob is too old, skipping bucket #{@frequency_bucket} ",
              { 'queued_time' => @queued_time, 'now' => Time.now, 'bucket' => @frequency_bucket })
    else
      Server.find(:all).each { |server|
        run(server) if server.is_active?
      }
    end
  end

  def run(server)
    if server.is_highest_frequency_bucket?(@frequency_bucket)
      Snapshot.take_snapshot(server, @frequency_bucket)
    else
      snapshot = Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(server, @frequency_bucket)
      if (snapshot)
        Snapshot.add_to_frequency_bucket(server, snapshot, @frequency_bucket)
      end
    end
  end

  # returns true if the time is older than one interval
  def job_too_old_to_run(frequency_bucket, time)
    (time + Server.get_interval_in_seconds(frequency_bucket)) < Time.now
  end
end
