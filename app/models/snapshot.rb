require 'mysql'

class Snapshot
  NAME_TAG = 'Name'
  FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def initialize(server, aws_snapshot)
    @server = server
    @aws_snapshot = aws_snapshot
  end
  
  delegate :id, :created_at, :state, :to => :aws_snapshot
  
  class << self
    def find(snapshot_id)
      snapshot = AWS.snapshots.get(snapshot_id)
      
      if snapshot
        server = Server.where(:system_backup_id => snapshot.tags['system-backup-id']).first
        new(server, snapshot) if server
      end
    end
  
    def tag_name(frequency_bucket)
      FREQUENCY_BUCKET_PREFIX + frequency_bucket
    end
    
    def create(server, volume_id, frequency_bucket)
      AWS.snapshots.create({'volumeId' => volume_id}).tap do |snapshot|
        AWS.tags.create({:resource_id => id, :key => NAME_TAG, :value => "snap of #{server.name}"})
        AWS.tags.create({:resource_id => id, :key => BACKUP_ID_TAG, :value => server.system_backup_id})
        AWS.tags.create({:resource_id => id, :key => self.tag_name(frequency_bucket), :value => nil})
        SnapshotEvent.log(server, 'create snapshot', "Snapshot (#{id}) started for bucket -> #{frequency_bucket}.")
      end
    end

    def take_snapshot(server, frequency_bucket)
      instance = server.instance
      if (!instance)
        custom_notify('NoInstanceToSnapshot', "Instance not found for: #{server.system_backup_id}",
                { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name})
        SnapshotEvent.log(server, 'create snapshot', "Failed Snapshot for bucket -> #{frequency_bucket}. instance not found for system-backup-id tag: #{server.system_backup_id}")
        return
      end

      if server.snapshot_in_progress?
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
        create(server, volume_id, frequency_bucket)

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
    
    def swallow_errors
      yield
    rescue RuntimeError => e
    end
  end

  def server 
    @server
  end
  
  def destroy
    aws_snapshot.destroy.tap do
      SnapshotEvent.log(server, 'destroy snapshot', "Snapshot #{id} destroyed.")
    end
  rescue RuntimeError => e
    custom_notify('AddTagToSnapshot', "Failed destroying Snapshot #{id}.",
            { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => id},
            e)
    SnapshotEvent.log(server, 'destroy snapshot', "Failed destroying Snapshot #{id}.", e)
  end

  def add_frequency_bucket(frequency_bucket)
    AWS.tags.create({:resource_id => id, :key => self.class.tag_name(frequency_bucket), :value => nil}).tap do
      SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{id} add to bucket -> #{frequency_bucket}.")
    end
    frequency_buckets << frequency_bucket unless frequency_bucket.include?(frequency_bucket)
  rescue RuntimeError => e
    custom_notify('AddTagToSnapshot', "Failed adding Snapshot #{id} to bucket -> #{frequency_bucket}.",
            { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => id, 'bucket' => frequency_bucket},
            e)
    SnapshotEvent.log(server, 'add frequency tag', "Failed adding Snapshot #{id} to bucket -> #{frequency_bucket}.", e)
  end

  def remove_frequency_bucket(frequency_bucket)
    AWS.delete_tags(id, self.class.tag_name(frequency_bucket) => nil).tap do
      SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{id} removed from bucket -> #{frequency_bucket}.")
    end
    frequency_buckets.delete(frequency_bucket) if frequency_bucket.include?(frequency_bucket)
  rescue RuntimeError => e
    custom_notify('RemoveTagFromSnapshot', "Failed removing Snapshot #{id} from bucket -> #{frequency_bucket}.",
            { 'system_backup_id' => server.system_backup_id, 'server_name' => server.name, 'snapshot_id' => id, 'bucket' => frequency_bucket},
            e)
    SnapshotEvent.log(server, 'remove frequency tag', "Failed removing Snapshot #{id} from bucket -> #{frequency_bucket}.", e)
  end
  
  def frequency_buckets
    @frequency_buckets ||= aws_snapshot.tags.inject([]) do |buckets, pair|
      tag, v = pair
      buckets << tag[FREQUENCY_BUCKET_PREFIX.length, tag.length] if tag.start_with?(FREQUENCY_BUCKET_PREFIX)
      buckets
    end
  end
  
private
  
  def aws_snapshot
    @aws_snapshot
  end
  
end
