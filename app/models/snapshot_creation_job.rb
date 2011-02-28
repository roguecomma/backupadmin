class SnapshotCreationJob < Struct.new(:frequency_bucket)
  def perform
    Server.find(:all).each { |server|
      run(server) if server.is_active?
    }
  end

  def run(server)
    puts("SnapshotCreationJob-> server=#{server.system_backup_id}, frequency_bucket="+ (self.frequency_bucket.to_s) +", time="+ (Time.now.to_s))
    if server.is_highest_frequency_bucket?(frequency_bucket)
      puts("SnapshotCreationJob-> server=#{server.system_backup_id}, "+ (self.frequency_bucket.to_s) +" new backup requested")
      if Snapshot.snapshot_in_progress?(server)
        SnapshotEvent.log(server, 'create snapshot skipped', "Snapshot already in progress, new snapshot not taken for #{frequency_bucket}.")
      else
        Snapshot.take_snapshot(server, frequency_bucket)
      end
    else
      puts("SnapshotCreationJob-> server=#{server.system_backup_id}, "+ (self.frequency_bucket.to_s) +" renaming a backup")
      snapshot = Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
      if (snapshot)
        Snapshot.add_to_frequency_bucket(server, snapshot, frequency_bucket)
      end
    end
  end
end
