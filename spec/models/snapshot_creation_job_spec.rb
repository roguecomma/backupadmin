require 'spec_helper'

describe SnapshotCreationJob do
  before(:each) {
    @server = create_server({:minute => 0, :hourly => 0, :daily => 1, :weekly => 1})
    @job = SnapshotCreationJob.new('daily')
    Snapshot.stub!(:take_snapshot)
    Snapshot.stub!(:add_to_frequency_bucket)
  }

  it 'should not create a new snapshot since one is already in progress' do
    Snapshot.stub!(:snapshot_in_progress?).and_return(true)
    Snapshot.should_receive(:take_snapshot).at_most(0).times
    SnapshotEvent.should_receive(:log)
    @job.run(@server)
  end

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
end
