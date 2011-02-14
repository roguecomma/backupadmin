require 'spec_helper'

describe Server do

  it 'get_highest_frequency_bucket should return nil if no buckets set' do
    server = Server.new
    server.get_highest_frequency_bucket.should == nil
  end

  it 'get_highest_frequency_bucket should return hourly if everything set' do
    server = Server.new
    server.hourly = 1
    server.daily = 1
    server.weekly = 1
    server.monthly = 1
    server.yearly = 1
    server.get_highest_frequency_bucket.should == 'hourly'
  end

  it 'get_highest_frequency_bucket should return daily when hourly and min are not set' do
    server = Server.new
    server.daily = 1
    server.get_highest_frequency_bucket.should == 'daily'
  end

  it 'get_highest_frequency_bucket should return weekly when daily, hourly, and min are not set' do
    server = Server.new
    server.weekly = 1
    server.get_highest_frequency_bucket.should == 'weekly'
  end

  it 'should create hourly and weekly cron jobs' do
    server = Server.new
    server.name = 'tst'
    server.hourly = 1
    server.weekly = 1
    server.remove_all_cron_entries
    CronEdit::Crontab.List['hourly-tst'].should be_nil
    CronEdit::Crontab.List['weekly-tst'].should be_nil
    server.register_cron_entries
    CronEdit::Crontab.List['hourly-tst'].should_not be_nil
    CronEdit::Crontab.List['daily-tst'].should be_nil
    CronEdit::Crontab.List['weekly-tst'].should_not be_nil
    server.remove_all_cron_entries
  end
end
