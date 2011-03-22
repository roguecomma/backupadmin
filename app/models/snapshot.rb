require 'net/ssh'
require 'mysql'

class Snapshot
  NAME_TAG = 'Name'
  BACKUP_ID_TAG = 'system-backup-id'
  FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def self.tag_name(frequency_bucket)
    FREQUENCY_BUCKET_PREFIX + frequency_bucket
  end

  def self.find(snapshot_id)
    AWS.snapshots.get(snapshot_id)
  end

  def self.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
    snapshots = self.filter_snapshots_for_buckets_sort_by_age(
                                 self.find_snapshots_for_server(server), 
                                 Server.get_higher_frequency_buckets(frequency_bucket))
    snapshots && snapshots[0] ? snapshots[0] : nil
  end

  def self.find_snapshots_for_server(server)
    self.fetch_snapshots({('tag:'+ BACKUP_ID_TAG) => server.system_backup_id})
  end

  def self.remove_snapshot(server, snapshot)
    begin
      snapshot.destroy
      SnapshotEvent.log(server, 'destroy snapshot', "Snapshot #{snapshot.id} destroyed.")
    rescue => e
      custom_notify('AddTagToSnapshot', "Failed destroying Snapshot #{snapshot.id}.",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => snapshot.id},
              e)
      SnapshotEvent.log(server, 'destroy snapshot', "Failed destroying Snapshot #{snapshot.id}.", e)
    end
  end

  def self.add_to_frequency_bucket(server, snapshot, frequency_bucket)
    begin
      self.create_tag(snapshot.id, self.tag_name(frequency_bucket))
      SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{snapshot.id} add to bucket -> #{frequency_bucket}.")
    rescue => e
      custom_notify('AddTagToSnapshot', "Failed adding Snapshot #{snapshot.id} to bucket -> #{frequency_bucket}.",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => snapshot.id, 'bucket' => frequency_bucket},
              e)
      SnapshotEvent.log(server, 'add frequency tag', "Failed adding Snapshot #{snapshot.id} to bucket -> #{frequency_bucket}.", e)
    end
  end

  def self.remove_from_frequency_bucket(server, snapshot, frequency_bucket)
    begin
      self.delete_tag(snapshot.id, self.tag_name(frequency_bucket))
      SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{snapshot.id} removed from bucket -> #{frequency_bucket}.")
    rescue => e
      custom_notify('RemoveTagFromSnapshot', "Failed removing Snapshot #{snapshot.id} from bucket -> #{frequency_bucket}.",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => snapshot.id, 'bucket' => frequency_bucket},
              e)
      SnapshotEvent.log(server, 'remove frequency tag', "Failed removing Snapshot #{snapshot.id} from bucket -> #{frequency_bucket}.", e)
    end
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

  def self.do_snapshot_create(server, volume_id, frequency_bucket)
    snapshot = AWS.snapshots.create({'volumeId' => volume_id})
    AWS.tags.create({:resource_id => snapshot.id, :key => NAME_TAG, :value => "snap of #{server.name}"})
    AWS.tags.create({:resource_id => snapshot.id, :key => BACKUP_ID_TAG, :value => server.system_backup_id})
    AWS.tags.create({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket), :value => nil})
    SnapshotEvent.log(server, 'create snapshot', "Snapshot (#{snapshot.id}) started for bucket -> #{frequency_bucket}.")
  end

  def self.take_snapshot(server, frequency_bucket)
    instance = self.get_instance_from_system_backup_id(server.system_backup_id)
    if (!instance)
      custom_notify('NoInstanceToSnapshot', "Instance not found for: #{server.system_backup_id}",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name})
      SnapshotEvent.log(server, 'create snapshot', "Failed Snapshot for bucket -> #{frequency_bucket}. instance not found for system-backup-id tag: #{server.system_backup_id}")
      return
    end

    ip = instance.public_ip_address
    volume_id = get_volume_id_for_block_device(instance, server.block_device)
    if snapshot_in_progress?(volume_id)
      custom_notify('SnapshotInProgress', "Snapshot in progress for: #{server.system_backup_id}",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'volume_id' => volume_id})
      SnapshotEvent.log(server, 'create snapshot', "Failed Snapshot for bucket -> #{frequency_bucket}. Snapshot currently in progress for system-backup-id tag: #{server.system_backup_id}")
      return
    end

    table_lock = false
    xfs_lock = false
    #mysql = Mysql.init()
    begin
      # mysql connection rejected..need proper credentials
      #mysql.connect(server.elastic_ip, server.ssh_user)
      #mysql.query("FLUSH TABLES WITH READ LOCK")
      server.ssh_exec "mysql -u root -e 'FLUSH TABLES WITH READ LOCK'", 'unable to get mysql table lock'
      table_lock = true
      server.ssh_exec "xfs_freeze -f #{server.mount_point}", 'unable to freeze xfs filesystem'
      xfs_lock = true

      # here we kick off the actual snapshot
      self.do_snapshot_create(server, volume_id, frequency_bucket)
      
      server.ssh_exec "xfs_freeze -u #{server.mount_point}", 'unable to un-freeze xfs filesystem'
      xfs_lock = false
      server.ssh_exec "mysql -u root -e 'UNLOCK TABLES'", 'unable to un-lock mysql tables'
      #mysql.query("UNLOCK TABLES")
      table_lock = false
    rescue => exception
      custom_notify('TakeSnapshotFailed', "Taking a Snapshot failed: #{server.system_backup_id}",
              { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'volume_id' => volume_id,
                'failure_message' => exception.message})
      SnapshotEvent.log(server, 'create snapshot', "Failed Snapshot for bucket -> #{frequency_bucket}. #{exception.message}")
    ensure
      swallow_errors { server.ssh_exec("xfs_freeze -u #{server.mount_point}") } if xfs_lock
      swallow_errors { server.ssh_exec("mysql -u root -e 'UNLOCK TABLES'") } if table_lock
      #mysql.query("UNLOCK TABLES") if table_lock
      #mysql.close()
    end
  end

  def self.get_instance_from_system_backup_id(system_backup_id)
    AWS.servers.all({('tag:'+ BACKUP_ID_TAG) => system_backup_id}).first
  end

  def self.service_check(server)
    # check that system_backup_id can find a server with an public_ip_address
    # verify that the block point is attached
    # verify that the volume exists (df -k or something)
  end

  def self.get_volume_id_for_block_device(instance, block_device)
    volume_id = nil
    instance.block_device_mapping.each {|dev|
      volume_id = dev['volumeId'] if dev['deviceName'] == block_device
    }
    volume_id
  end

  def self.snapshot_in_progress?(volume_id)
    snapshots = self.fetch_snapshots({('volume-id') => volume_id})
    snapshots && snapshots.find{|s| s.state != "completed" } ? true : false
  end

private
  # This method farmed out for easy mocking
  def self.fetch_snapshots(attributes)
    AWS.snapshots.all(attributes)
  end

  def self.create_tag(id, tag)
    AWS.tags.create({:resource_id => id, :key => tag, :value => nil})
  end

  def self.delete_tag(id, tag)
    ## BUG -- resource-id just can't be used in filter for some reason..skipping for now
    #tags = AWS.tags.all({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket)})
    
    # These two commands work but require an extra call to AWS
    #tags = AWS.tags.all({:key => self.tag_name(frequency_bucket)})

    #tags.each {|t| t.destroy if t.resource_id == snapshot.id } if tags
    AWS.delete_tags(id, tag => nil)
  end
  
  def swallow_errors
    yield
  rescue RuntimeError => e
  end
  
end
