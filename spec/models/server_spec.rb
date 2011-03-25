require 'spec_helper'

describe Server do

  describe '.highest_frequency_bucket' do
    it 'should return nil if no buckets set' do
      server = Server.new
      server.minute = 0
      server.hourly = 0
      server.daily = 0
      server.weekly = 0
      server.monthly = 0
      server.quarterly = 0
      server.yearly = 0
      server.highest_frequency_bucket.should == nil
    end

    it 'should return hourly if everything set' do
      server = Server.new
      server.minute = 0
      server.hourly = 1
      server.daily = 1
      server.weekly = 1
      server.monthly = 1
      server.yearly = 1
      server.highest_frequency_bucket.should == 'hourly'
    end
    
    it 'should return daily when hourly and min are not set' do
      server = Server.new
      server.minute = 0
      server.hourly = 0
      server.daily = 1
      server.highest_frequency_bucket.should == 'daily'
    end

    it 'should return weekly when daily, hourly, and min are not set' do
      server = Server.new
      server.minute = 0
      server.hourly = 0
      server.daily = 0
      server.weekly = 1
      server.highest_frequency_bucket.should == 'weekly'
    end
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
  
  describe '#instance' do
    it 'should be nil if no servers are tagged with the backup id' do
      create_server.instance.should == nil
    end
    
    it 'should return a single instance tagged with the backup id' do
      server = create_server
      3.times { AWS.run_instances 'ami-123', 1, 1 }
      instance = AWS.servers[1]
      AWS.create_tags instance.id, {'system-backup-id' => server.system_backup_id}
      
      server.instance.id.should == instance.id
    end
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
      
      @hourly = create_snapshot(:server => @server, :volume => @volume, :tags => {
        'frequency-bucket-hourly' => nil
      })
      @daily = create_snapshot(:server => @server, :volume => @volume, :tags => {
        'frequency-bucket-daily' => nil
      })
    end
    
    it 'should include snapshots for single matching bucket' do
      @server.snapshots_for_frequency_buckets('daily').map(&:id).should == [@daily.id]
    end
    
    it 'should include snapshots for multiple matching buckets' do
      @server.snapshots_for_frequency_buckets('daily', 'hourly').map(&:id).sort.should == [@daily, @hourly].map(&:id).sort
    end
    
    it 'should not include snapshots for unmatched buckets' do
      weekly = create_snapshot(:server => @server, :volume => @volume, :tags => {
        'frequency-bucket-weekly' => nil
      })
      
      @server.snapshots_for_frequency_buckets('daily', 'hourly').map(&:id).sort.should == [@daily, @hourly].map(&:id).sort
    end
  end
  
  describe '#oldest_higher_frequency_snapshot' do
    before(:each) do
      @server = create_server
      @volume = AWS.volumes.create(:availability_zone => 'us-east-1d', :size => '100G').reload      
    end
    
    it 'should return nil if not other snapshots' do
      @server.oldest_higher_frequency_snapshot('yearly').should == nil
    end
    
    it 'should return nil for the most frequent bucket' do
      create_snapshot(:server => @server, :volume => @volume, :tags => {
        "frequency-bucket-#{@server.highest_frequency_bucket}" => nil
      })
      
      @server.oldest_higher_frequency_snapshot(@server.highest_frequency_bucket).should == nil
    end
    
    it 'should return the oldest snapshot of a higher frequency' do
      # old, but not less frequent
      Timecop.freeze(6.hours.ago) do
        create_snapshot(:server => @server, :volume => @volume, :tags => {
          "frequency-bucket-monthly" => nil
        })
      end
      # old, and more frequent
      Timecop.freeze(5.hours.ago) do
        @oldest = create_snapshot(:server => @server, :volume => @volume, :tags => {
          "frequency-bucket-weekly" => nil
        })
      end
      # newer, but more frequent
      Timecop.freeze(4.hours.ago) do
        create_snapshot(:server => @server, :volume => @volume, :tags => {
          "frequency-bucket-daily" => nil
        })
      end
      
      @server.oldest_higher_frequency_snapshot('monthly').id.should == @oldest.id
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
