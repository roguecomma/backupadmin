class BackupJob < Struct.new(:server_id, :frequency_bucket)
  def perform
    server = Server.find(server_id)
    if server.is_active?
      run_backup(server)
      remove_unneeded_backups(server)
    end
  end

  def run_backup(server)
    puts("BackupJob-> server_id="+ (self.server_id.to_s) +", frequency_bucket="+ (self.frequency_bucket.to_s) +", time="+ (Time.now.to_s))
    if server.is_highest_frequency_bucket?(frequency_bucket)
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.frequency_bucket.to_s) +"] new backup requested")
      if Snapshot.snapshot_in_progress?(server)
        SnapshotEvent.log(server, 'create snapshot skipped', "Snapshot already in progress, new snapshot not taken for #{frequency_bucket}.")
      else
        Snapshot.take_snapshot(server, frequency_bucket)
      end
    else
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.frequency_bucket.to_s) +"] renaming a backup")
      snapshot = Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
      if (snapshot)
        Snapshot.add_to_frequency_bucket(snapshot, frequency_bucket)
      end
    end
  end

  def remove_unneeded_backups
    snapshots = Snapshot.find_snapshots_no_longer_needed(server_id, frequency_bucket, server.get_number_allowed(frequency_bucket))
    if (snapshots)
      snapshots.each {|snapshot|
        if (Snapshot.get_frequency_buckets(snapshot).length == 1)
          Snapshot.remove_snapshot(snapshot)
        else
          Snapshot.remove_from_frequency_bucket(snapshot, frequency_bucket)
        end
      }
    end
  end
end
