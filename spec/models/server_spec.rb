require 'spec_helper'

describe Server do

  it 'get_highest_frequency_bucket should return nil if no buckets set' do
    server = Server.new
    server.minute = 0
    server.hourly = 0
    server.daily = 0
    server.weekly = 0
    server.monthly = 0
    server.quarterly = 0
    server.yearly = 0
    server.get_highest_frequency_bucket.should == nil
  end

  it 'get_highest_frequency_bucket should return hourly if everything set' do
    server = Server.new
    server.minute = 0
    server.hourly = 1
    server.daily = 1
    server.weekly = 1
    server.monthly = 1
    server.yearly = 1
    server.get_highest_frequency_bucket.should == 'hourly'
  end

  it 'should get_number_allowed' do
    server = Server.new
    server.hourly = 0
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
    server.minute = 0
    server.hourly = 0
    server.daily = 1
    server.get_highest_frequency_bucket.should == 'daily'
  end

  it 'get_highest_frequency_bucket should return weekly when daily, hourly, and min are not set' do
    server = Server.new
    server.minute = 0
    server.hourly = 0
    server.daily = 0
    server.weekly = 1
    server.get_highest_frequency_bucket.should == 'weekly'
  end
  
  describe '#snapshots' do
    before(:each) do
      @server = create_server
      @volume = AWS.volumes.create(:availability_zone => 'us-east-1d', :size => '100G')
    end
    
    it 'should return snapshots tagged for the server' do
      good = []
      2.times do
        snap = AWS.snapshots.create(:volume_id => @volume.id)
        AWS.create_tags(snap.id, 'system-backup-id' => @server.system_backup_id)
        good << snap
      end
      
      @server.snapshots.map(&:id).sort.should == good.map(&:id).sort
    end
    
    it 'should not include snapshots for other servers' do
      bad = AWS.snapshots.create(:volume_id => @volume.id)
      AWS.create_tags(bad.id, 'system-backup-id' => 'something else')
      
      @server.snapshots.should_not include(bad)
    end
    
    it 'should be ordered by created_at' do
      array = []
      [2,1,4,5,0,3].map do |i|
        Timecop.freeze(Time.now - i.hours) do 
          array << AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
            AWS.create_tags(snap.id, 'system-backup-id' => @server.system_backup_id)
          end
        end
      end
    
      @server.snapshots.map(&:id).should == array.sort_by(&:created_at).map(&:id)
    end
  end
  
  describe '#snapshots_for_frequency_buckets' do
    before(:each) do
      @server = create_server
      @volume = AWS.volumes.create(:availability_zone => 'us-east-1d', :size => '100G').reload
      
      @hourly = Snapshot.new(@server, AWS.snapshots.create(:volume_id => @volume.id))
      AWS.create_tags(@hourly.id, 
        'system-backup-id' => @server.system_backup_id,
        'frequency-bucket-hourly' => nil)
        
      @daily = Snapshot.new(@server, AWS.snapshots.create(:volume_id => @volume.id).reload)
      AWS.create_tags(@daily.id, 
        'system-backup-id' => @server.system_backup_id,
        'frequency-bucket-daily' => nil)
    end
    
    it 'should include snapshots for single matching bucket' do
      @server.snapshots_for_frequency_buckets('daily').map(&:id).should == [@daily.id]
    end
    
    it 'should include snapshots for multiple matching buckets' do
      @server.snapshots_for_frequency_buckets('daily', 'hourly').map(&:id).sort.should == [@daily, @hourly].map(&:id).sort
    end
    
    it 'should not include snapshots for unmatched buckets' do
      weekly = AWS.snapshots.create(:volume_id => @volume.id)
      AWS.create_tags(weekly.id, 
        'system-backup-id' => @server.system_backup_id,
        'frequency-bucket-weekly' => nil)
      
      @server.snapshots_for_frequency_buckets('daily', 'hourly').map(&:id).sort.should == [@daily, @hourly].map(&:id).sort
    end
  end
  
  # describe 'with a set of snapshots' do
  #   before(:each) do
  #     @snapshot_h1 = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("hourly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 1.hour
  #     end
  #     
  #     @snapshot_h2 = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("hourly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 2.hours
  #     end
  #     
  #     @snapshot_d = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("daily") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 1.day
  #     end
  #     
  #     @snapshot_w = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("weekly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 1.week
  #     end
  #     
  #     @snapshot_m = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("monthly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 30.days
  #     end
  #     
  #     @snapshot_q = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("quarterly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 90.days
  #     end
  #     
  #     @snapshot_y = AWS.snapshots.create(:volume_id => @volume.id).tap do |snap|
  #       AWS.create_tags(snap.id, Snapshot.tag_name("yearly") => nil, 'system-backup-id' => @server.system_backup_id)
  #       snap.created_at = Time.now - 150.days
  #     end
  #   end
  # end
end
