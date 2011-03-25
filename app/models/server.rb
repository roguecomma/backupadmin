require 'net/ssh'

class Server < ActiveRecord::Base
  BACKUP_ID_TAG = 'system-backup-id'
  
  # Keep these in order from highest to lowest frequency
  FREQUENCY_BUCKETS = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  scope :active, where(:state => 'active')
  
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
    return FREQUENCY_BUCKETS.slice(0, FREQUENCY_BUCKETS.index(frequency_bucket))
  end
  
  def get_number_allowed(frequency_bucket)
    respond_to?(frequency_bucket) ? send(frequency_bucket) : 0
  end
  
  def ssh_exec(command, exception_string = nil)
    command = sudo_command(command) if sudo?
    Net::SSH.start(ip, ssh_user) do |ssh|
      ssh_output = ssh.exec!(command)
      raise "#{exception_string}: #{command} - #{ssh_output}" if ssh_output && exception_string
    end
  end
  
  def instance
    @instance ||= AWS.servers.all(backup_set_filter).first
  end
  
  def volume_id
    mapping = instance.block_device_mapping.detect{|m| m['deviceName'] == block_device}
    mapping['volumeId'] if mapping
  end
  
  def ip
    instance.ip_address
  end
  
  def snapshots
    @snapshots ||= AWS.snapshots.all(backup_set_filter).sort_by(&:created_at).map{|s| Snapshot.new(self, s)}
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
  
  def service_check
    # check that system_backup_id can find a server with an public_ip_address
    # verify that the block point is attached
    # verify that the volume exists (df -k or something)
  end
  
  def reload
    @instance = nil
    @snapshots = nil
    self
  end
  
  private 
    
    def sudo_command(command)
      "sudo env PATH=$PATH #{command}"
    end
    
    def sudo?
      ssh_user != 'root'
    end
    
    def backup_set_filter
      {"tag:#{BACKUP_ID_TAG}" => system_backup_id}
    end
    
end
