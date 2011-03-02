require 'spec_helper'

describe SnapshotCreationJob do
  before(:each) {
    @server = create_server({:minute => 0, :hourly => 0, :daily => 1, :weekly => 1})
    @job = SnapshotCreationJob.new('daily')
    Snapshot.stub!(:do_snapshot_create)
    Snapshot.stub!(:add_to_frequency_bucket)
    Snapshot.stub!(:run_ssh_command)
  }

  it 'should create a new snapshot' do
    Snapshot.stub!(:snapshot_in_progress?).and_return(false)
    Snapshot.should_receive(:take_snapshot).with(@server, 'daily')
    @job.run(@server)
  end

  it 'should put snapshot into another frequency bucket' do
    @snapshot = create_fake_snapshot({:created_at => Time.now - (24*60*60), :tags => {Snapshot.tag_name('daily') => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @job.frequency_bucket = 'weekly'
    Snapshot.stub!(:find_oldest_snapshot_in_higher_frequency_buckets).and_return(@snapshot)
    Snapshot.stub!(:add_to_frequency_bucket)
    Snapshot.should_receive(:add_to_frequency_bucket).with(@server, @snapshot, 'weekly')
    @job.run(@server)
  end

  it 'should do nothing since not most frequent and no snapshots' do
    @job.frequency_bucket = 'weekly'
    Snapshot.stub!(:find_oldest_snapshot_in_higher_frequency_buckets).and_return(nil)
    Snapshot.should_receive(:add_to_frequency_bucket).at_most(0).times
    @job.run(@server)
  end

  it 'should return calculate when too old to run' do
    @job.too_old_to_run('minute', Time.now).should be_false
    @job.too_old_to_run('minute', Time.now - (60*60)).should be_true
    @job.too_old_to_run('hourly', Time.now - (59*60)).should be_false
    @job.too_old_to_run('hourly', Time.now - (61*60)).should be_true
    @job.too_old_to_run('daily', Time.now - (23*60*60)).should be_false
    @job.too_old_to_run('daily', Time.now - (25*60*60)).should be_true
    @job.too_old_to_run('weekly', Time.now - (6*24*60*60)).should be_false
    @job.too_old_to_run('weekly', Time.now - (8*24*60*60)).should be_true
    @job.too_old_to_run('monthly', Time.now - (30*24*60*60)).should be_false
    @job.too_old_to_run('monthly', Time.now - (32*24*60*60)).should be_true
    @job.too_old_to_run('quarterly', Time.now - (89*24*60*60)).should be_false
    @job.too_old_to_run('quarterly', Time.now - (91*24*60*60)).should be_true
    @job.too_old_to_run('yearly', Time.now - (364*24*60*60)).should be_false
    @job.too_old_to_run('yearly', Time.now - (366*24*60*60)).should be_true
  end
end
