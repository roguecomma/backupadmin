namespace :cron do
  desc 'update cron on this box'
  task :register_jobs => :environment do |t|
    name = 'backupadmin'
    CronEdit::Crontab.Remove "minute-"+ name
    CronEdit::Crontab.Remove "hourly-"+ name
    CronEdit::Crontab.Remove "daily-"+ name
    CronEdit::Crontab.Remove "weekly-"+ name
    CronEdit::Crontab.Remove "monthly-"+ name
    CronEdit::Crontab.Remove "quarterly-"+ name
    CronEdit::Crontab.Remove "yearly-"+ name
    CronEdit::Crontab.Add "minute-"+ name, "13,33,53 * * * * "+ creation_commandline('minute')
    CronEdit::Crontab.Add "hourly-"+ name, "11 * * * * "+ creation_commandline('hourly')
    CronEdit::Crontab.Add "daily-"+ name, "9 0 * * 1,2,3,4,5,6,7 "+ creation_commandline('daily')
    CronEdit::Crontab.Add "weekly-"+ name, "7 0 1,8,15,22 * * "+ creation_commandline('weekly')
    CronEdit::Crontab.Add "monthly-"+ name, "5 0 1 * * "+ creation_commandline('monthly')
    CronEdit::Crontab.Add "quarterly-"+ name, "3 0 1 1,4,7,10 * "+ creation_commandline('quarterly')
    CronEdit::Crontab.Add "yearly-"+ name, "1 0 1 1 * "+ creation_commandline('yearly')
    CronEdit::Crontab.Add "remove-snapshots-"+ name, "15,35,55 * * * * "+ removal_commandline()
  end

  def creation_commandline(frequency_bucket)
    create_cron_commandline("SnapshotCreationJob.new(\""+ frequency_bucket +"\")")
  end

  def removal_commandline()
    create_cron_commandline("SnapshotRemovalJob.new")
  end

  def create_cron_commandline(command)
    "cd "+ (::Rails.root.to_s) +" && script/rails runner -e "+ (Rails.env.to_s) +" 'Delayed::Job.enqueue(#{command})'"
  end
end
