class SnapshotCreationJob < Struct.new(:frequency_bucket, :queued_time)

  def initialize(bucket, time=Time.now)
    self.frequency_bucket = bucket
    self.queued_time = time
  end

  def perform
    if self.job_too_old_to_run(frequency_bucket, queued_time)
      CustomNotifier.notify(
        {:error_class => 'DJ Slow', 
          :error_message => "SnapshotCreationJob is too old, skipping bucket #{frequency_bucket}"},
        { 'queued_time' => queued_time, 'now' => Time.now, 'bucket' => frequency_bucket })
    else
      Server.active.each { |server| run(server) }
    end
  end

  def run(server)
    if server.is_highest_frequency_bucket?(frequency_bucket)
      Delayed::Job.enqueue(TakeSnapshotJob.new(frequency_bucket, server.id, queued_time))
    else
      if (snapshot = server.oldest_higher_frequency_snapshot(frequency_bucket))
        snapshot.add_frequency_bucket(frequency_bucket)
      end
    end
  end

  # returns true if the time is older than one interval
  def self.job_too_old_to_run(frequency_bucket, time)
    (time + Server.get_interval_in_seconds(frequency_bucket)) < Time.now
  end
end
