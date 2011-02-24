class Snapshot
  @@NAME_TAG = 'system-backup-id'
  @@FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def self.find(snapshot_id)
    aws_connection.snapshots.get(snapshot_id)
  end

  def self.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
    snapshots = []
    # run through all higher frequency, rejecting any dups
    Server.get_higher_frequency_buckets(frequency_bucket).each {|bucket|
      id_list = snapshots.collect{|s| s.id}
      snapshots |= self.fetch_snapshots({'tag-key' => (@@FREQUENCY_BUCKET_PREFIX + bucket),
                        ('tag:'+ @@NAME_TAG) => server.elastic_ip}).reject {|s| id_list.include?(s.id)}
    }
    # sort by date, oldest first
    snapshots.sort! {|x,y| x.created_at <=> y.created_at}
    #puts snapshots.inspect
    #puts snapshots[0].id if snapshots[0]
    snapshots[0] ? snapshots[0] : nil
  end

  def self.find_snapshots_no_longer_needed(server, frequency_bucket, number_allowed)
    snapshots = self.fetch_snapshots({'tag-key' => (@@FREQUENCY_BUCKET_PREFIX + frequency_bucket), ('tag:'+ @@NAME_TAG) => server.elastic_ip})
    snapshots.sort! {|x,y| x.created_at <=> y.created_at} if snapshots
    snapshots && snapshots.length > number_allowed ? snapshots.slice(0, snapshots.length - number_allowed) : nil
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
        buckets << tag[@@FREQUENCY_BUCKET_PREFIX.length, tag.length] if tag.start_with?(@@FREQUENCY_BUCKET_PREFIX)
      }
    end
    buckets
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
