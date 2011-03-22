class Server < ActiveRecord::Base
  has_many :backups

  BACKUP_ID_TAG = 'system-backup-id'
  
  # Keep these in order from highest to lowest frequency
  FREQUENCY_BUCKETS = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  def is_active?
    state == 'active'
  end

  def is_highest_frequency_bucket?(tag)
    tag == get_highest_frequency_bucket
  end

  def get_highest_frequency_bucket
    FREQUENCY_BUCKETS.select{|frequency_bucket| respond_to?(frequency_bucket +'?') && send(frequency_bucket +'?')}.first
  end

  def get_number_allowed(frequency_bucket)
    respond_to?(frequency_bucket) ? send(frequency_bucket) : 0
  end

  def self.get_higher_frequency_buckets(frequency_bucket)
    return FREQUENCY_BUCKETS.slice(0, FREQUENCY_BUCKETS.index(frequency_bucket))
  end

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
  
  def ssh_exec(command, exception_string = nil)
    command = sudo_command(command) if sudo?
    Net::SSH.start(ip, ssh_user) do |ssh|
      ssh_output = ssh.exec!(command)
      raise "#{exception_string}: #{command} - #{ssh_output}" if ssh_output && exception_string
    end
  end
  
  def ip
    instance.ip_address
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
    
    def instance
      @instance ||= AWS.servers.all(backup_set_filter).first
    end    
end
