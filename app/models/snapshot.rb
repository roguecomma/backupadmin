require 'net/ssh'
require 'mysql'

class Snapshot
  BACKUP_ID_TAG = 'system-backup-id'
  FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def self.tag_name(frequency_bucket)
    FREQUENCY_BUCKET_PREFIX + frequency_bucket
  end

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
    self.fetch_snapshots({('tag:'+ BACKUP_ID_TAG) => server.system_backup_id})
  end

  def self.remove_snapshot(server, snapshot)
    snapshot.destroy
    SnapshotEvent.log(server, 'destroy snapshot', "Snapshot #{snapshot.id} destroyed.")
  end

  def self.add_to_frequency_bucket(server, snapshot, frequency_bucket)
    aws_connection.tags.create({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket), :value => nil})
    SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{snapshot.id} add to bucket -> #{frequency_bucket}.")
  end

  def self.remove_from_frequency_bucket(server, snapshot, frequency_bucket)
    ## BUG -- resource-id just can't be used in filter for some reason..skipping for now
    #tags = aws_connection.tags.all({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket)})
    
    # These two commands work
    #tags = aws_connection.tags.all({:key => self.tag_name(frequency_bucket)})
    #tags.each {|t| t.destroy if t.resource_id == snapshot.id } if tags

    # This lower level call works, output is wacky though
    aws_connection.delete_tags(snapshot.id, self.tag_name(frequency_bucket) => nil)
    SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{snapshot.id} removed from bucket -> #{frequency_bucket}.")
  end

  # handle this..it exists elswhere currently
  #def self.snapshot_in_progress?(server)
  #  # filter for snapshots not in pending state
  #end

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

  def self.do_snapshot_create(server, volume_id, frequency_bucket)
    snapshot = aws_connection.snapshots.create({'volumeId' => volume_id, :description => "snap of #{server.name}"})
    aws_connection.tags.create({:resource_id => snapshot.id, :key => BACKUP_ID_TAG, :value => server.system_backup_id})
    aws_connection.tags.create({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket), :value => nil})
    SnapshotEvent.log(server, 'create snapshot', "Snapshot (#{snapshot.id}) started for bucket -> #{frequency_bucket}.")
  end

  def self.take_snapshot(server, frequency_bucket)
    instance = self.get_instance_from_system_backup_id(server.system_backup_id)
    if (!instance)
      SnapshotEvent.log(server, 'create snapshot', "Failed Snapshot for bucket -> #{frequency_bucket}. instance not found for system-backup-id tag: #{server.system_backup_id}")
      return
    end

    ip = instance.ip_address
    volume_id = get_volume_id_for_block_device(instance, server.block_device)
    if snapshot_in_progress?(volume_id)
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
      self.run_ssh_command(server, ip, "mysql -u root -e 'FLUSH TABLES WITH READ LOCK'")
      table_lock = true
      self.run_ssh_command(server, ip, "xfs_freeze -f #{server.mount_point}")
      xfs_lock = true

      # here we kick off the actual snapshot
      self.do_snapshot_create(server, volume_id, frequency_bucket)
      
      self.run_ssh_command(server, ip, "xfs_freeze -u #{server.mount_point}")
      xfs_lock = false
      self.run_ssh_command(server, ip, "mysql -u root -e 'UNLOCK TABLES'")
      #mysql.query("UNLOCK TABLES")
      table_lock = false
    ensure
      self.run_ssh_command(server, ip, "xfs_freeze -u #{server.mount_point}") if xfs_lock
      self.run_ssh_command(server, ip, "mysql -u root -e 'UNLOCK TABLES'") if table_lock
      #mysql.query("UNLOCK TABLES") if table_lock
      #mysql.close()
    end
  end

  def self.run_ssh_command(server, ip, command)
    Net::SSH.start(ip, server.ssh_user) do |ssh|
      puts ssh.exec!(server.ssh_user == 'root' ? command : "sudo env PATH=$PATH #{command}")
    end
  end

  def self.get_instance_from_system_backup_id(system_backup_id)
    instances = aws_connection.servers.all({('tag:'+ BACKUP_ID_TAG) => system_backup_id})
    instances ? instances[0] : nil
  end

  def self.service_check(server)
    # check that system_backup_id can find a server with an ip_address
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
end
