require 'spec_helper'

describe SnapshotRemovalJob do
  before(:each) {
    @job = SnapshotRemovalJob.new
    @snapshot_h1 = create_fake_snapshot({:created_at => Time.now - (60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}hourly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_h2 = create_fake_snapshot({:created_at => Time.now - (2*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}hourly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_d = create_fake_snapshot({:created_at => Time.now - (24*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}daily" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_w = create_fake_snapshot({:created_at => Time.now - (7*24*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}weekly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_m = create_fake_snapshot({:created_at => Time.now - (30*24*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}monthly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_q = create_fake_snapshot({:created_at => Time.now - (90*24*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}quarterly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_y = create_fake_snapshot({:created_at => Time.now - (150*24*60*60), :tags => {"#{Snapshot::FREQUENCY_BUCKET_PREFIX}yearly" => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    Snapshot.stub!(:remove_snapshot)
    Snapshot.stub!(:remove_from_frequency_bucket)
  }

  it 'should not remove backup if backup still tagged' do
    @snapshot_h2.tags["#{Snapshot::FREQUENCY_BUCKET_PREFIX}daily"] = nil
    Snapshot.stub!(:remove_snapshot)
    Snapshot.should_receive(:remove_snapshot).at_most(0).times
    Snapshot.should_receive(:remove_from_frequency_bucket).with(@snapshot_h2, 'hourly')
    @job.remove_unneeded_snapshots([@snapshot_h1, @snapshot_h2], 'hourly', 1)
  end

  it 'should remove backup since has only 1 tag' do
    Snapshot.stub!(:remove_snapshot)
    Snapshot.should_receive(:remove_snapshot).with(@snapshot_h2)
    Snapshot.should_receive(:remove_from_frequency_bucket).at_most(0).times
    @job.remove_unneeded_snapshots([@snapshot_h1, @snapshot_h2], 'hourly', 1)
  end

  it 'should remove all backups since none allowed' do
    Snapshot.stub!(:remove_snapshot)
    Snapshot.should_receive(:remove_snapshot).with(@snapshot_h2)
    Snapshot.should_receive(:remove_snapshot).with(@snapshot_h1)
    Snapshot.should_receive(:remove_from_frequency_bucket).at_most(0).times
    @job.remove_unneeded_snapshots([@snapshot_h1, @snapshot_h2], 'hourly', 0)
  end

  it 'should not remove any' do
    Snapshot.should_receive(:remove_snapshot).at_most(0).times
    Snapshot.should_receive(:remove_from_frequency_bucket).at_most(0).times
    @job.remove_unneeded_snapshots([@snapshot_h1, @snapshot_h2], 'hourly', 2)
  end
end
