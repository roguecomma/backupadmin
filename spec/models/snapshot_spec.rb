require 'spec_helper'

describe Snapshot do
  before(:each) {
    @server = create_server()
    @snapshot_h1 = create_fake_snapshot({:created_at => Time.now - (60*60), :tags => {'frequency-bucket-hourly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_h2 = create_fake_snapshot({:created_at => Time.now - (2*60*60), :tags => {'frequency-bucket-hourly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_d = create_fake_snapshot({:created_at => Time.now - (24*60*60), :tags => {'frequency-bucket-daily' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_w = create_fake_snapshot({:created_at => Time.now - (7*24*60*60), :tags => {'frequency-bucket-weekly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_m = create_fake_snapshot({:created_at => Time.now - (30*24*60*60), :tags => {'frequency-bucket-monthly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_q = create_fake_snapshot({:created_at => Time.now - (90*24*60*60), :tags => {'frequency-bucket-quarterly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_y = create_fake_snapshot({:created_at => Time.now - (150*24*60*60), :tags => {'frequency-bucket-yearly' => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
  }

  describe 'with find oldest backup in younger tags' do

    it 'should find oldest backup in younger tags' do
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2] }
      Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'daily').should eql(@snapshot_h2)
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2, @snapshot_d] }
      Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'weekly').should eql(@snapshot_d)
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2, @snapshot_d, @snapshot_w] }
      Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'monthly').should eql(@snapshot_w)
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2, @snapshot_d, @snapshot_w, @snapshot_m] }
      Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'quarterly').should eql(@snapshot_m)
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2, @snapshot_d, @snapshot_w, @snapshot_q] }
      Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'yearly').should eql(@snapshot_q)
    end

    it 'should find backups no longer needed ' do
      Snapshot.stub!(:fetch_snapshots).and_return { [@snapshot_h1, @snapshot_h2] }
      Snapshot.find_snapshots_no_longer_needed(@server, 'hourly', 4).should be_nil
      Snapshot.find_snapshots_no_longer_needed(@server, 'hourly', 1)[0].should eql(@snapshot_h2)
      Snapshot.find_snapshots_no_longer_needed(@server, 'hourly', 0).length.should eql(2)
      Snapshot.find_snapshots_no_longer_needed(@server, 'hourly', 2).should be_nil
      Snapshot.find_snapshots_no_longer_needed(@server, 'hourly', 3).should be_nil
    end
  end
end
