class Snapshot
  BACKUP_ID_TAG = 'system-backup-id'
  FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def self.find(snapshot_id)
    aws_connection.snapshots.get(snapshot_id)
  end

  def self.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
    snapshots = self.filter_snapshots_for_buckets_sort_by_age(
                                 self.find_snapshots_for_server(server), 
                                 Server.get_higher_frequency_buckets(frequency_bucket))
    snapshots && snapshots[0] ? snapshots[0] : nil
  end

  def self.find_snapshots_for_server(server)
    self.fetch_snapshots({('tag:'+ BACKUP_ID_TAG) => server.elastic_ip})
  end

  def self.take_snapshot(server, frequency_bucket)
    SnapshotEvent.log(server, 'create snapshot', "Snapshot started for bucket -> #{frequency_bucket}.")
  end

  def self.remove_snapshot(snapshot)
    #snapshot.destroy
    SnapshotEvent.log(server, 'destroy snapshot', "Snapshot #{snapshot.id} destroyed.")
  end

  def self.add_to_frequency_bucket(snapshot, frequency_bucket)
    SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{snapshot.id} add to bucket -> #{frequency_bucket}.")
  end

  def self.remove_from_frequency_bucket(snapshot, frequency_bucket)
    SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{snapshot.id} removed from bucket -> #{frequency_bucket}.")
  end

  def self.snapshot_in_progress?(server)
    # filter for snapshots not in pending state
  end

  def self.get_frequency_buckets(snapshot)
    buckets = []
    if snapshot && snapshot.tags
      snapshot.tags.each {|tag,v|
        buckets << tag[FREQUENCY_BUCKET_PREFIX.length, tag.length] if tag.start_with?(FREQUENCY_BUCKET_PREFIX)
      }
    end
    buckets
  end

  def self.filter_snapshots_for_buckets_sort_by_age(snapshots, frequency_buckets)
    s = snapshots.reject { |snapshot| (get_frequency_buckets(snapshot) & frequency_buckets).length == 0 } if snapshots
    s.sort! {|x,y| x.created_at <=> y.created_at} if s
    s
  end

  # This method farmed out for easy mocking
  def self.fetch_snapshots(attributes)
    aws_connection.snapshots.all(attributes)
  end

  # Builds a connection to AWS
  def self.aws_connection
    @connection ||= Fog::Compute.new(
      :provider => 'AWS',
      :aws_access_key_id => AppConfig.ec2['access_key_id'],
      :aws_secret_access_key => AppConfig.ec2['secret_access_key']
    )
  end

end
