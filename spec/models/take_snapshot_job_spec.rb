require 'spec_helper'

describe TakeSnapshotJob do
  before(:each) do
    @time = Time.now
    @job = TakeSnapshotJob.new('daily', 44, @time)
  end
  
  describe 'initialize' do
    it 'should set frequency_bucket' do
      @job.frequency_bucket.should == 'daily'
    end
    
    it 'should set id' do
      @job.server_id.should == 44
    end

    it 'should set queued_time' do
      @job.queued_time.should == @time
    end
  end

  it 'should return correct delayed time from reschedule_at' do
    @job.reschedule_at(@time, 0).should == (@time + 30)
  end
end
