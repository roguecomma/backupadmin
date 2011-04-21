require 'spec_helper'

describe Snapshot do
  before(:each) do
    @server = create_server
    @volume = AWS.volumes.create(:availability_zone => 'us-east-1d', :size => '100G')
  end
  
  after(:each) do
    Delayed::Worker.delay_jobs = true
  end
  
  describe '.find' do
    before(:each) do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
      AWS.create_tags(@aws_snapshot.id, Server::BACKUP_ID_TAG => @server.system_backup_id)
    end
    
    it 'should return a snapshot wrapping the aws object' do
      snapshot = Snapshot.find(@aws_snapshot.id)
      snapshot.should be_instance_of(Snapshot)
      snapshot.id.should == @aws_snapshot.id
    end

    it 'should return nil for a nonexistent snapshot' do
      Snapshot.find('zzz').should == nil
    end
    
    it 'should look up server for snapshot' do
      snapshot = Snapshot.find(@aws_snapshot.id)
      snapshot.server.should == @server
    end
  end

  describe '.create' do
    before(:each) do
      @snapshot = Snapshot.create(@server, @volume.id, 'daily')
    end
    
    it 'should create a snapshot for the volume' do
      @snapshot.volume_id = @volume.id
    end
  end
  
  describe '.report_action' do
    it "should raise exception for known aws issue 1 #{Snapshot::AWS_FAILURE_1}" do
      expect { Snapshot.report_action(@server, 'nuttin', 'no message') { raise Snapshot::AWS_FAILURE_1 } }.to raise_error(Snapshot::AWS_FAILURE_1)
    end

    it "should raise exception for known aws issue 2 #{Snapshot::AWS_FAILURE_1}" do
      expect { Snapshot.report_action(@server, 'nuttin', 'no message') { raise Snapshot::AWS_FAILURE_2 } }.to raise_error(Snapshot::AWS_FAILURE_2)
    end

    it "should not raise exception for any non-known exception" do
      Snapshot.report_action(@server, 'nuttin', 'will be a message') { raise 'this will be swallowed' }
    end
  end
  
  describe '.recent_untagged_snapshot_found_and_processed' do
    before(:each) do
      #@aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
      #@snapshot = Snapshot.new(@server, @aws_snapshot)
    end

    it 'should do nothing if most recent snapshot properly tagged' do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id)
      @aws_snapshot.tags = {Snapshot::NAME_TAG => 'something'}
      Snapshot.stub!(:find_most_recent_snapshot).and_return(Snapshot.new(@server, @aws_snapshot))
      Snapshot.should_not_receive(:add_initial_tags)
      Snapshot.recent_untagged_snapshot_found_and_processed!(@server, 'minute')
    end

    it 'should do nothing if most recent snapshot created too old' do
      Timecop.freeze(10.minutes.ago) { @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id) }
      @server.stub!(:volume_id).and_return(@aws_snapshot.volume_id)
      Snapshot.should_receive(:add_initial_tags)
      Snapshot.recent_untagged_snapshot_found_and_processed!(@server, 'minute')
    end

    it 'should attempt to tag the most recent improperly tagged snapshot' do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id)
      @server.stub!(:volume_id).and_return(@aws_snapshot.volume_id)
      Snapshot.should_receive(:add_initial_tags)
      Snapshot.recent_untagged_snapshot_found_and_processed!(@server, 'minute')
    end
    
  end
  
  describe '#frequency_buckets' do
    before(:each) do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
      @snapshot = Snapshot.new(@server, @aws_snapshot)
    end
    
    it 'should extract buckets from tags' do
      AWS.create_tags(@snapshot.id,
        Snapshot.tag_name("monthly") => nil, 
        Snapshot.tag_name("yearly") => nil
      )
      @aws_snapshot.reload
      
      @snapshot.frequency_buckets.should == ["monthly", "yearly"]
    end
    
    it 'should ignore junk tags' do
      aws = create_fake_snapshot({:tags => {
        Snapshot.tag_name("monthly") => nil, 
        Snapshot.tag_name("daily") => nil,
        'junk' => 'daily',
        "whipple#{Snapshot::FREQUENCY_BUCKET_PREFIX}whipple" => nil,
        Server::BACKUP_ID_TAG => 'test.host'}})
        
      snap = Snapshot.new(@server, aws)
      snap.frequency_buckets.should == ["monthly", "daily"]
    end
  end
  
  describe '#add_frequency_bucket' do
    before(:each) do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
      @snapshot = Snapshot.new(@server, @aws_snapshot)    
      Delayed::Worker.delay_jobs = false 
    end
    
    it 'should raise exception if add tag raises exception' do
      AWS.stub!(:create_tags).and_raise("hey")
      
      expect { @snapshot.add_frequency_bucket('daily') }.to raise_error("hey")
    end

    it 'should not raise exception if add tag raises Fog::Service::NotFound' do
      AWS.stub!(:create_tags).and_raise(Fog::Service::NotFound.new('failure'))
      @snapshot.add_frequency_bucket('daily')
      @snapshot.frequency_buckets.should_not include('daily')
    end

    it 'should add tag to snapshot' do
      @snapshot.add_frequency_bucket('daily')
      @snapshot.frequency_buckets.should include('daily')
    end
  end
  
  describe '#remove_frequency_bucket' do
    before(:each) do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id).reload
      @snapshot = Snapshot.new(@server, @aws_snapshot)
      @snapshot.add_frequency_bucket('daily')
    end
    
    it 'should log tag removal failure and complete job successfully if snapshot doesnt exist' do
      Delayed::Worker.delay_jobs = false
      Snapshot.stub!(:find).and_return(nil)
      AWS.should_not_receive(:delete_tags)
      @snapshot.remove_frequency_bucket('daily')
    end

    it 'should raise exception if delete tag raises exception' do
      Delayed::Worker.delay_jobs = false
      Snapshot.stub!(:find).and_return(@snapshot)
      AWS.stub!(:delete_tags).and_raise("hey")
      
      expect { @snapshot.remove_frequency_bucket('daily') }.to raise_error("hey")
    end

    it 'should remove the frequency tag' do
      @snapshot.remove_frequency_bucket('daily')
      @snapshot.frequency_buckets.should_not include('daily')
    end
  end

  describe '#destroy' do
    before(:each) do
      @aws_snapshot = AWS.snapshots.create(:volume_id => @volume.id)
      @snapshot = Snapshot.new(@server, @aws_snapshot)
    end
    
    it 'should destroy the underlying snapshot' do
      @aws_snapshot.should_receive(:destroy)
      @snapshot.destroy
    end
    
    it 'should raise exception if remove snapshot raises exception' do
      @aws_snapshot.stub!(:destroy).and_raise("NO!")
      HoptoadNotifier.should_receive(:notify)
      @snapshot.destroy
    end
  end
end
