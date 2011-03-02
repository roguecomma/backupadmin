class SnapshotCreationJob < Struct.new(:frequency_bucket)

  def initialize(bucket)
    @frequency_bucket = bucket
    @queued_time = Time.now
  end

  def perform
    if job_too_old_to_run(@frequency_bucket, @queued_time)
      puts "RUN: job is too old, skipping #{@queued_time} - #{Time.now}"
      # do hoptoad notification thinger here
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
