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

  it 'should get_number_allowed' do
    server = Server.new
    server.get_number_allowed('hourly').should be(0)
    server.hourly = 1
    server.daily = 2
    server.weekly = 3
    server.monthly = 4
    server.yearly = 5
    server.get_number_allowed('hourly').should be(1)
    server.hourly = 7
    server.get_number_allowed('hourly').should be(7)
    server.get_number_allowed('daily').should be(2)
    server.get_number_allowed('weekly').should be(3)
    server.get_number_allowed('monthly').should be(4)
    server.get_number_allowed('yearly').should be(5)
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
end
