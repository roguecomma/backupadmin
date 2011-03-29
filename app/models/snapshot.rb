require 'mysql'

class Snapshot
  NAME_TAG = 'Name'
  FREQUENCY_BUCKET_PREFIX = 'frequency-bucket-'

  def initialize(server, aws_snapshot)
    @server = server
    @aws_snapshot = aws_snapshot
  end
  
  delegate :id, :created_at, :state, :volume_id, :to => :aws_snapshot
  
  class << self
    def find(snapshot_id)
      snapshot = AWS.snapshots.get(snapshot_id)
      
      if snapshot
        # TODO: refactor so that the tag name doesn't leak outside Server.  Server.for_snapshot(x)
        server = Server.where(:system_backup_id => snapshot.tags[Server::BACKUP_ID_TAG]).first
        new(server, snapshot) if server
      end
    end
  
    def tag_name(frequency_bucket)
      FREQUENCY_BUCKET_PREFIX + frequency_bucket
    end
    
    def create(server, volume_id, frequency_bucket)
      AWS.snapshots.create('volume_id' => volume_id).tap do |snapshot|
        AWS.tags.create({:resource_id => snapshot.id, :key => NAME_TAG, :value => "snap of #{server.name}"})
        AWS.tags.create({:resource_id => snapshot.id, :key => Server::BACKUP_ID_TAG, :value => server.system_backup_id})
        AWS.tags.create({:resource_id => snapshot.id, :key => self.tag_name(frequency_bucket), :value => nil})
        SnapshotEvent.log(server, 'create snapshot', "Snapshot (#{snapshot.id}) started for bucket -> #{frequency_bucket}.")
      end
    end

    def take_snapshot(server, frequency_bucket)
      report_action(server, 'create snapshot', "Snapshot for bucket -> #{frequency_bucket}") do
        server.service_check!
        instance = server.instance
        table_lock = false
        xfs_lock = false
        mysql = Mysql.init()
      
        # Port forwarding over ssh won't work unless we put this code in a sep thread
        #ssh.forward.local(1234, server.ip, 3306)
        #ssh.loop { true }
      
        begin
          mysql.connect(server.ip, server.mysql_user, server.mysql_password)
          mysql.query("FLUSH TABLES WITH READ LOCK")
          table_lock = true
          server.ssh_exec("xfs_freeze -f #{server.mount_point}")
          xfs_lock = true

          # here we kick off the actual snapshot
          create(server, server.volume_id, frequency_bucket)

          server.ssh_exec("xfs_freeze -u #{server.mount_point}")
          xfs_lock = false
          mysql.query("UNLOCK TABLES")
          table_lock = false
        ensure
          swallow_errors { server.ssh_exec("xfs_freeze -u #{server.mount_point}") } if xfs_lock
          swallow_errors { mysql.query("UNLOCK TABLES") if table_lock } if table_lock
          mysql.close()
        end
      end
    end

    def report_action(server, action, message)
      yield.tap do
        SnapshotEvent.log(server, action, message)
      end
    rescue RuntimeError => e
      swallow_errors do
        SnapshotEvent.log(server, action, "FAILED: #{message}")
        CustomNotifier.notify(e, {
          'action' => action,
          'message' => message,
          'server' => server.attributes,            
          'snapshot_id' => id
        })
      end
    end
    
    private
    
      def swallow_errors
        yield
      rescue RuntimeError => e
      end    

  end

  def server 
    @server
  end
  
  def destroy
    self.class.report_action(server, 'destroy snapshot', "Destroying snapshot #{id}.") do
      aws_snapshot.destroy
    end
  end

  def add_frequency_bucket(frequency_bucket)
    delay.add_bucket_tag(frequency_bucket)
    frequency_buckets << frequency_bucket unless frequency_bucket.include?(frequency_bucket)
  end

  def remove_frequency_bucket(frequency_bucket)
    delay.remove_bucket_tag(frequency_bucket)
    frequency_buckets.delete(frequency_bucket) if frequency_bucket.include?(frequency_bucket)
  end
  
  def frequency_buckets
    @frequency_buckets ||= aws_snapshot.tags.inject([]) do |buckets, pair|
      tag, v = pair
      buckets << tag[FREQUENCY_BUCKET_PREFIX.length, tag.length] if tag.start_with?(FREQUENCY_BUCKET_PREFIX)
      buckets
    end
  end
  
private
  
  def add_bucket_tag(frequency_bucket)
    AWS.tags.create({:resource_id => id, :key => self.class.tag_name(frequency_bucket), :value => nil}).tap do
      SnapshotEvent.log(server, 'add frequency tag', "Snapshot #{id} add to bucket -> #{frequency_bucket}.")
    end
  end
  
  def remove_bucket_tag(frequency_bucket)
    AWS.delete_tags(id, self.class.tag_name(frequency_bucket) => nil).tap do
      SnapshotEvent.log(server, 'remove frequency tag', "Snapshot #{id} removed from bucket -> #{frequency_bucket}.")
    end
  end
  
  def aws_snapshot
    @aws_snapshot
  end
  
end
