class Server < ActiveRecord::Base
  has_many :backups

  # Keep these in order from lowest to highest frequency
  @@frequency_buckets = ['minute', 'hourly', 'daily', 'weekly', 'monthly', 'quarterly', 'yearly']

  def is_active?
    state? && state == 'active'
  end

  def is_highest_frequency_bucket?(tag)
    tag == get_highest_frequency_bucket
  end

  def get_highest_frequency_bucket
    @@frequency_buckets.select{|frequency_bucket| respond_to?(frequency_bucket +'?') && send(frequency_bucket +'?')}.first
  end

  def get_number_allowed(frequency_bucket)
    respond_to?(frequency_bucket) ? send(frequency_bucket) : 0
  end

  def self.get_higher_frequency_buckets(frequency_bucket)
    return @@frequency_buckets.slice(0, @@frequency_buckets.index(frequency_bucket))
  end

  def register_cron_entries
    remove_all_cron_entries
    CronEdit::Crontab.Add "minute-"+ name, "13,33,53 * * * * "+ create_cron_commandline(id, 'minute') if minute?
    CronEdit::Crontab.Add "hourly-"+ name, "11 * * * * "+ create_cron_commandline(id, 'hourly') if hourly?
    CronEdit::Crontab.Add "daily-"+ name, "9 0 * * 1,2,3,4,5,6,7 "+ create_cron_commandline(id, 'daily') if daily?
    CronEdit::Crontab.Add "weekly-"+ name, "7 0 1,8,15,22 * * "+ create_cron_commandline(id, 'weekly') if weekly?
    CronEdit::Crontab.Add "monthly-"+ name, "5 0 1 * * "+ create_cron_commandline(id, 'monthly') if monthly?
    CronEdit::Crontab.Add "quarterly-"+ name, "3 0 1 1,4,7,10 * "+ create_cron_commandline(id, 'quarterly') if quarterly?
    CronEdit::Crontab.Add "yearly-"+ name, "1 0 1 1 * "+ create_cron_commandline(id, 'yearly') if yearly?
  end

  def remove_all_cron_entries
    CronEdit::Crontab.Remove "minute-"+ name
    CronEdit::Crontab.Remove "hourly-"+ name
    CronEdit::Crontab.Remove "daily-"+ name
    CronEdit::Crontab.Remove "weekly-"+ name
    CronEdit::Crontab.Remove "monthly-"+ name
    CronEdit::Crontab.Remove "quarterly-"+ name
    CronEdit::Crontab.Remove "yearly-"+ name
  end

  def create_cron_commandline(server_id, frequency_bucket)
    "cd "+ (::Rails.root.to_s) +" && script/rails runner -e "+ (Rails.env.to_s) +" 'Delayed::Job.enqueue(BackupJob.new("+ (server_id.to_s) +", \""+ frequency_bucket +"\"))'"
  end

end
