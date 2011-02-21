require 'spec_helper'

describe BackupJob do
  before(:each) {
    @server = create_server({:daily => 1, :weekly => 1})
    @backup_job = BackupJob.new(@server.id, 'daily')
    @backup_job.stub!(:remove_backup_volume).and_return { }
    @backup_job.stub!(:create_backup_volume).and_return { 'backup-vol-id' }
  }

  it 'should create a new backup' do
    @backup_job.should_receive(:create_backup_volume).with(@server).and_return('backup-vol-id')
    @backup_job.run_backup
    Backup.find(:first).backup_tags[0].tag.should == 'daily'
  end

  it 'should add another tag' do
    @backup_job.should_receive(:create_backup_volume).with(@server).and_return('backup-vol-id')
    @backup_job.run_backup
    Backup.find(:first).backup_tags[0].tag.should == 'daily'
    @backup_job.tag = 'weekly'
    @backup_job.should_receive(:create_backup_volume).at_most(0).times
    @backup_job.run_backup
    Backup.find(:first).backup_tags.length.should eql(2)
  end

  describe 'with backups' do
    @backup_vol = 'backup vol'
    before(:each) {
      # Set the times appropriately then test
      @backup_d1 = create_backup_with_tag({:server => @server, :snapshot_started => Time.now - (60*60), :volume_id => 'd1'}, 'daily')
      @backup_d2 = create_backup_with_tag({:server => @server, :snapshot_started => Time.now - (2*60*60), :volume_id => 'd2'}, 'daily')
      @backup_w = create_backup_with_tag({:server => @server, :snapshot_started => Time.now - (7*24*60*60), :volume_id => 'w'}, 'weekly')
    }

    it 'should not remove backup if backup still tagged' do
      b2 = create_backup_tag(:backup => @backup_d2, :tag => 'monthly')
      BackupTag.find_all_by_backup_id(@backup_d2.id).length.should be(2)
      @backup_job.should_receive(:remove_backup_volume).at_most(0).times
      @backup_job.remove_unneeded_backups
      Backup.find(@backup_d2.id)
      BackupTag.find_all_by_backup_id(@backup_d2.id).length.should be(1)
    end

    it 'should remove unneeded backups with none to remove' do
      @server.daily = 2
      @server.save!
      @backup_job.should_receive(:remove_backup_volume).at_most(0).times
      @backup_job.remove_unneeded_backups
      Backup.find(@backup_d1.id)
      Backup.find(@backup_d2.id)
    end

    it 'should remove unneeded backups with some to remove' do
      @backup_job.should_receive(:remove_backup_volume).with('d2')
      @backup_job.remove_unneeded_backups
      Backup.find(@backup_d1.id)
      Backup.find_all_by_id(@backup_d2.id).length.should be(0)
      BackupTag.find_all_by_backup_id(@backup_d2.id).length.should be(0)
    end

    it 'should remove unneeded backups with two to remove' do
      @server.daily = 0
      @server.save!
      @backup_job.should_receive(:remove_backup_volume).with('d1').with('d2')
      @backup_job.remove_unneeded_backups
      Backup.find_all_by_id(@backup_d1.id).length.should be(0)
      BackupTag.find_all_by_backup_id(@backup_d1.id).length.should be(0)
      Backup.find_all_by_id(@backup_d2.id).length.should be(0)
      BackupTag.find_all_by_backup_id(@backup_d2.id).length.should be(0)
    end
  end
end
