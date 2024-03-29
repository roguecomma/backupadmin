require 'net/ssh'

class Server < ActiveRecord::Base
  IN_PROGRESS_ERROR = 'snapshot DJ job already in progress, not starting'
  BACKUP_ID_TAG = 'system-backup-id'
  
  # Keep these in order from highest to lowest frequency
  FREQUENCY_BUCKETS = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  SNAPSHOT_TYPES = ['MysqlSnapshot', 'Snapshot']

  attr_accessor :tmp_ssh_key
  validates_presence_of :name, :hostname, :snapshot_type
  validates_numericality_of :minute, :hourly, :daily, :weekly, :monthly, :quarterly, :yearly, 
                            :allows_nil => false, :greater_than_or_equal_to => 0
  
  scope :active, where(:state => 'active')
  
  after_create :set_system_backup_id
  before_validation :update_ssh_key
  
  def self.get_interval_in_seconds(frequency_bucket)
    return case frequency_bucket
      when 'minute'     then 20.minutes
      when 'hourly'     then 1.hour
      when 'daily'      then 1.day
      when 'weekly'     then 1.week
      when 'monthly'    then 30.days
      when 'quarterly'  then 90.days
      when 'yearly'     then 1.year
    end
  end
  
  def active?
    state == 'active'
  end

  def is_highest_frequency_bucket?(tag)
    tag == highest_frequency_bucket
  end

  def highest_frequency_bucket
    FREQUENCY_BUCKETS.select{|frequency_bucket| respond_to?(frequency_bucket +'?') && send(frequency_bucket +'?')}.first
  end

  def higher_frequency_buckets(frequency_bucket)
    FREQUENCY_BUCKETS.slice(0, FREQUENCY_BUCKETS.index(frequency_bucket))
  end

  def snapshot_class
    snapshot_type.constantize
  end

  def get_number_allowed(frequency_bucket)
    respond_to?(frequency_bucket) ? send(frequency_bucket) : 0
  end
  
  def ssh_exec(command, exception_string = nil)
    command = sudo_command(command) if sudo?
    options = ssh_key ? {:key_data => [ssh_key], :keys_only => true} : {}
    exit_status = 999999
    Net::SSH.start(ip, ssh_user, options) do |ssh|
      ssh.open_channel do |chan|
        chan.on_request('exit-status') { |ch, data| exit_status = data.read_long }
        chan.exec(command)
      end
    end
    raise "#{exception_string}: #{command} - bad exit status: #{exit_status}" if exit_status != 0 && exception_string
  end
  
  def seed
    if snapshots.empty?
      snapshot = snapshot_class.take_snapshot(self, highest_frequency_bucket)
      FREQUENCY_BUCKETS.each { |bucket| snapshot.add_frequency_bucket(bucket) unless get_number_allowed(bucket) == 0 || bucket == highest_frequency_bucket }
    else
      oldest = snapshots.first
      FREQUENCY_BUCKETS.each do |bucket|
        oldest.add_frequency_bucket(bucket) unless get_number_allowed(bucket) == 0 || !snapshots_for_frequency_buckets(bucket).empty?
      end
    end
  end

  def instance
    @instance ||= AWS.servers.all(instance_filter).first
  end
  
  def volume_id
    mapping = instance.block_device_mapping.detect{|m| m['deviceName'] == block_device}
    mapping['volumeId'] if mapping
  end
  
  def ip
    instance.dns_name
  end
  
  def snapshots
    @snapshots ||= AWS.snapshots.all(snapshot_filter).sort_by(&:created_at).map{|s| snapshot_class.new(self, s)}
  end
  
  def snapshots_for_frequency_buckets(*buckets) 
    snapshots.reject { |s| (s.frequency_buckets & buckets).empty? }
  end
  
  def oldest_higher_frequency_snapshot(frequency_bucket)
    snapshots_for_frequency_buckets(*higher_frequency_buckets(frequency_bucket)).first
  end
  
  def snapshot_in_progress?
    !!AWS.snapshots.all('volume-id' => volume_id).detect{|s| !s.ready?}
  end
  
  def service_check!
    raise "missing instance" unless instance
    raise "missing volume_id" unless volume_id
    raise "snapshot already in progress" if snapshot_in_progress?
  end
  
  def reload
    @instance = nil
    @snapshots = nil
    self
  end
  
  def self.record_snapshot_starting(server)
    affected_rows = update_all(["snapshot_job_started = now()"], ["id=? and snapshot_job_started is null", server.id])
    raise IN_PROGRESS_ERROR if affected_rows == 0
    true
  end

  def self.record_snapshot_stopping(server)
    update_all(["snapshot_job_started = null"], ["id=?", server.id])
  end

  private 
    
    def sudo_command(command)
      "sudo #{command}"
    end
    
    def sudo?
      ssh_user != 'root'
    end
    
    def snapshot_filter
      {"tag:#{BACKUP_ID_TAG}" => system_backup_id}
    end
    
    def instance_filter
      {'dns-name' => hostname}
    end
    
    def set_system_backup_id
      self.update_attribute(:system_backup_id, "#{id}-#{name.underscore.gsub(/[_ ]/, '-')}")
    end

    def update_ssh_key
      self.ssh_key=tmp_ssh_key if tmp_ssh_key && tmp_ssh_key.length > 0
    end
end
