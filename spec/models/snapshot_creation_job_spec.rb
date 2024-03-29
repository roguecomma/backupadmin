require 'spec_helper'

describe SnapshotCreationJob do
  before(:each) do
    @server = create_server({:minute => 0, :hourly => 0, :daily => 1, :weekly => 1})
    @volume = AWS.volumes.create(:availability_zone => 'us-east-1d', :size => '100G')
    @job = SnapshotCreationJob.new('daily')
  end
  
  after(:each) do
    Delayed::Worker.delay_jobs = true
  end
  
  describe 'initialize' do
    it 'should set frequency_bucket' do
      @job.frequency_bucket.should == 'daily'
    end
    
    it 'should set queued_time' do
      @job.queued_time.should be_within(1).of(Time.now)
    end
  end

  it 'should create a new snapshot' do
    Delayed::Worker.delay_jobs = false
    Snapshot.stub!(:snapshot_in_progress?).and_return(false)
    Snapshot.should_receive(:take_snapshot).with(@server, 'daily')
    @job.run(@server)
  end

  it 'should notify Airbrake dj is slow' do
    SnapshotCreationJob.stub!(:job_too_old_to_run).and_return(true)
    Airbrake.should_receive(:notify)
    @job.perform
  end

  it 'should put snapshot into another frequency bucket' do
    Delayed::Worker.delay_jobs = false
    aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
    aws_snapshot.created_at = Time.now - 1.day
    AWS.create_tags aws_snapshot.id, Snapshot.tag_name('daily') => nil, Server::BACKUP_ID_TAG => @server.system_backup_id
    @snapshot = Snapshot.new(@server, aws_snapshot)

    @job = SnapshotCreationJob.new('yearly')
    @job.run(@server)
    @snapshot.frequency_buckets.should include('yearly')
  end

  it 'should do nothing since not most frequent and no snapshots' do
    @job = SnapshotCreationJob.new('weekly')
    Snapshot.should_not_receive(:take_snapshot)
    @job.run(@server)
  end

  it 'should return calculate when too old to run' do
    SnapshotCreationJob.job_too_old_to_run('minute', Time.now).should be_false
    SnapshotCreationJob.job_too_old_to_run('minute', Time.now - 1.hour).should be_true
    SnapshotCreationJob.job_too_old_to_run('hourly', Time.now - 59.minutes).should be_false
    SnapshotCreationJob.job_too_old_to_run('hourly', Time.now - 61.minutes).should be_true
    SnapshotCreationJob.job_too_old_to_run('daily', Time.now - 23.hours).should be_false
    SnapshotCreationJob.job_too_old_to_run('daily', Time.now - 25.hours).should be_true
    SnapshotCreationJob.job_too_old_to_run('weekly', Time.now - 6.days).should be_false
    SnapshotCreationJob.job_too_old_to_run('weekly', Time.now - 8.days).should be_true
    SnapshotCreationJob.job_too_old_to_run('monthly', Time.now - 29.days).should be_false
    SnapshotCreationJob.job_too_old_to_run('monthly', Time.now - 31.days).should be_true
    SnapshotCreationJob.job_too_old_to_run('quarterly', Time.now - 89.days).should be_false
    SnapshotCreationJob.job_too_old_to_run('quarterly', Time.now - 91.days).should be_true
    SnapshotCreationJob.job_too_old_to_run('yearly', Time.now - 364.days).should be_false
    SnapshotCreationJob.job_too_old_to_run('yearly', Time.now - 366.days).should be_true
  end
end
