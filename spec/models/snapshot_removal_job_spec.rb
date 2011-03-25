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

  describe 'with two backups' do
    before(:each) do
      @snapshots = []
      Timecop.freeze(2.hours.ago) do
        @snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
          Snapshot.tag_name("hourly") => nil
        })
      end
      Timecop.freeze(1.hour.ago) do
        @snapshots << create_snapshot(:volume => @volume, :server => @server, :tags => {
          Snapshot.tag_name("hourly") => nil
        })
      end
    end
  
    describe 'and one allowed' do
      it 'should remove oldest snapshot' do
        @job.remove_unneeded_snapshots(@server, 'hourly', 1)
        @server.reload.snapshots.map(&:id).should == [@snapshots[1].id]
      end
    end

    describe 'and none allowed' do
      it 'should remove all snapshots' do
        @job.remove_unneeded_snapshots(@server, 'hourly', 0)
        @server.reload.snapshots.should == []
      end
    end
    
    describe 'with two allowed' do
      it 'should not remove any' do
        @job.remove_unneeded_snapshots(@server, 'hourly', 2)
        @server.reload.snapshots.map(&:id).should == @snapshots.map(&:id)
      end
    end
  end
end
