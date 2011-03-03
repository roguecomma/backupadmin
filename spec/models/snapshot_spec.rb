require 'spec_helper'

describe Snapshot do
  before(:each) {
    @server = create_server()
    @snapshot_h1 = create_fake_snapshot({:created_at => Time.now - (60*60), :tags => {Snapshot.tag_name("hourly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_h2 = create_fake_snapshot({:created_at => Time.now - (2*60*60), :tags => {Snapshot.tag_name("hourly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_d = create_fake_snapshot({:created_at => Time.now - (24*60*60), :tags => {Snapshot.tag_name("daily") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_w = create_fake_snapshot({:created_at => Time.now - (7*24*60*60), :tags => {Snapshot.tag_name("weekly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_m = create_fake_snapshot({:created_at => Time.now - (30*24*60*60), :tags => {Snapshot.tag_name("monthly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_q = create_fake_snapshot({:created_at => Time.now - (90*24*60*60), :tags => {Snapshot.tag_name("quarterly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
    @snapshot_y = create_fake_snapshot({:created_at => Time.now - (150*24*60*60), :tags => {Snapshot.tag_name("yearly") => nil, 'system-backup-id' => 'some.elastic.ip.com'}})
  }

  it 'should get the correct frequency buckets from the tags' do
    Snapshot.get_frequency_buckets(@snapshot_h1).should eql(['hourly'])
    @snapshot_h1.tags[Snapshot.tag_name("weekly")] = nil
    Snapshot.get_frequency_buckets(@snapshot_h1).should include('hourly', 'weekly')
    @snapshot_h1.tags[Snapshot.tag_name("weekly")] = nil
    @snapshot_h1.tags[Snapshot.tag_name("daily")] = nil
    @snapshot_h1.tags[Snapshot.tag_name("monkey")] = nil
    @snapshot_h1.tags['junk'] = nil
    @snapshot_h1.tags["otherstuff#{Snapshot::FREQUENCY_BUCKET_PREFIX}whipple"] = nil
    Snapshot.get_frequency_buckets(@snapshot_h1).should include('hourly', 'weekly', 'daily', 'monkey')
  end

  it 'should filter and sort correctly' do
    ordered = [@snapshot_y, @snapshot_q, @snapshot_m, @snapshot_w, @snapshot_d, @snapshot_h2, @snapshot_h1]
    backwards = [@snapshot_h1, @snapshot_h2, @snapshot_d, @snapshot_w, @snapshot_m, @snapshot_q, @snapshot_y]
    mixed = [@snapshot_m, @snapshot_h1, @snapshot_d, @snapshot_q, @snapshot_y, @snapshot_w, @snapshot_h2]
    Snapshot.filter_snapshots_for_buckets_sort_by_age(mixed, ['hourly']).should eql([@snapshot_h2, @snapshot_h1])
    Snapshot.filter_snapshots_for_buckets_sort_by_age(mixed, ['daily','hourly']).should eql([@snapshot_d, @snapshot_h2, @snapshot_h1])
    Snapshot.filter_snapshots_for_buckets_sort_by_age(mixed, ['daily','hourly','yearly']).should eql([@snapshot_y, @snapshot_d, @snapshot_h2, @snapshot_h1])
    Snapshot.filter_snapshots_for_buckets_sort_by_age(mixed, Server::FREQUENCY_BUCKETS).should eql(ordered)
    Snapshot.filter_snapshots_for_buckets_sort_by_age(backwards, Server::FREQUENCY_BUCKETS).should eql(ordered)
    Snapshot.filter_snapshots_for_buckets_sort_by_age(ordered, Server::FREQUENCY_BUCKETS).should eql(ordered)
  end

  it 'should find oldest snapshot in higher frequency buckets' do
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
    Snapshot.stub!(:fetch_snapshots).and_return { [] }
    Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(@server, 'yearly').should be_nil
  end

  # unfortunately untestable at this time..need to mock Net::SSH
  #it 'should raise exception if ssh returns data' do
  #  Net::SSH.stub!(:start).and_return { ssh_output = 'some output' }
  #  lambda { Snapshot.run_ssh_command(@server, nil, 'cmd', 'exc string') }.should raise_error
  #end
  #it 'should not raise exception if ssh returns no data' do
  #  Net::SSH.stub!(:start)
  #  lambda { Snapshot.run_ssh_command(@server, nil, 'cmd', 'exc string') }.should_not raise_error
  #end

  it 'should raise exception if delete tag raises exception' do
    Snapshot.stub!(:delete_tag).and_return{raise 'hey'}
    HoptoadNotifier.should_receive(:notify)
    Snapshot.remove_from_frequency_bucket(@server, @snapshot_h1, 'daily')
  end

  it 'should not raise exception if delete tag does not raise exception' do
    Snapshot.stub!(:delete_tag)
    HoptoadNotifier.should_receive(:notify).at_most(0).times
    Snapshot.remove_from_frequency_bucket(@server, @snapshot_h1, 'daily')
  end

  it 'should raise exception if add tag raises exception' do
    Snapshot.stub!(:create_tag).and_return{raise 'hey'}
    HoptoadNotifier.should_receive(:notify)
    Snapshot.add_to_frequency_bucket(@server, @snapshot_h1, 'daily')
  end

  it 'should not raise exception if add tag does not raise exception' do
    Snapshot.stub!(:create_tag)
    HoptoadNotifier.should_receive(:notify).at_most(0).times
    Snapshot.add_to_frequency_bucket(@server, @snapshot_h1, 'daily')
  end

  it 'should raise exception if remove snapshot raises exception' do
    @snapshot_h1.stub!(:destroy).and_return{raise 'hey'}
    HoptoadNotifier.should_receive(:notify)
    Snapshot.remove_snapshot(@server, @snapshot_h1)
  end

  it 'should not raise exception if remove snapshot does not raise exception' do
    @snapshot_h1.stub!(:destroy)
    HoptoadNotifier.should_receive(:notify).at_most(0).times
    Snapshot.remove_snapshot(@server, @snapshot_h1)
  end
end
