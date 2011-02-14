class Server < ActiveRecord::Base
  has_many :backups

  def is_highest_frequency_bucket?(bucket)
    bucket == get_highest_frequency_bucket
  end

  def get_highest_frequency_bucket
    #return 'minute' if minute?
    return 'hourly' if hourly?
    return 'daily' if daily?
    return 'weekly' if weekly?
    return 'monthly' if monthly?
    #return 'quarterly' if quarterly?
    return 'yearly' if yearly?
    return nil
  end

  def register_cron_entries
    remove_all_cron_entries
    CronEdit::Crontab.Add "hourly-"+ name, "4 * * * * "+ create_cron_commandline(id, 'hourly') if hourly?
    CronEdit::Crontab.Add "daily-"+ name, "7 0 * * 1,2,3,4,5,6,7 "+ create_cron_commandline(id, 'daily') if daily?
    CronEdit::Crontab.Add "weekly-"+ name, "12 0 1,8,15,22 * * "+ create_cron_commandline(id, 'weekly') if weekly?
    CronEdit::Crontab.Add "monthly-"+ name, "15 0 1 * * "+ create_cron_commandline(id, 'monthly') if monthly?
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

  def create_cron_commandline(server_id, bucket)
    "cd "+ (::Rails.root.to_s) +" && script/rails runner -e "+ (Rails.env.to_s) +" 'Delayed::Job.enqueue(BackupJob.new("+ (server_id.to_s) +", \""+ bucket +"\"))'"
  end

end
