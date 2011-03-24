require 'spec_helper'

describe SnapshotRemovalJob do
  before(:each) do
    @job = SnapshotRemovalJob.new
    @server = create_server
    @volume = create_volume
  end
  
  it 'should not remove backup if backup still tagged' do
    snapshot = create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("daily") => nil,
      Snapshot.tag_name("hourly") => nil
    })
    snapshot.instance_eval{aws_snapshot}.should_not_receive(:destroy)
    
    @job.remove_unneeded_snapshots(@server, 'hourly', 1)
  end

  it 'should remove backup since has only 1 tag' do
    snapshot = create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("hourly") => nil
    })
    snapshot.instance_eval{aws_snapshot}.should_not_receive(:destroy)
    @job.remove_unneeded_snapshots(@server, 'hourly', 1)
  end

  it 'should remove all backups since none allowed' do
    snapshots = []
    snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("hourly") => nil
    })
    snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("hourly") => nil
    })
    snapshots.each{|s| s.instance_eval{aws_snapshot}.should_receive(:destroy)}
    
    @job.remove_unneeded_snapshots(@server, 'hourly', 0)
  end

  it 'should not remove any' do
    snapshots = []
    snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("hourly") => nil
    })
    snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
      Snapshot.tag_name("hourly") => nil
    })
    snapshots.each{|s| s.instance_eval{aws_snapshot}.should_not_receive(:destroy)}
    
    @job.remove_unneeded_snapshots(@server, 'hourly', 2)
  end
end
