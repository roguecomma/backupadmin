require 'spec_helper'

describe Backup do
  before(:each) {
    @backup = create_backup()
  }

  describe 'with find oldest backup in younger tags' do
    before(:each) {
      # Set the times appropriately then test
      @backup_h1 = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (60*60)}, 'hourly')
      @backup_h2 = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (2*60*60)}, 'hourly')
      @backup_d = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (24*60*60)}, 'daily')
      @backup_w = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (7*24*60*60)}, 'weekly')
      @backup_m = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (30*24*60*60)}, 'monthly')
      @backup_q = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (90*24*60*60)}, 'quarterly')
      @backup_y = create_backup_with_tag({:server => @backup.server, :snapshot_started => Time.now - (150*24*60*60)}, 'yearly')
    }

    it 'should find oldest backup in younger tags' do
      Backup.find_oldest_backup_amongst_younger_tags(@backup.server, 'daily').should eql(@backup_h2)
      Backup.find_oldest_backup_amongst_younger_tags(@backup.server, 'weekly').should eql(@backup_d)
      Backup.find_oldest_backup_amongst_younger_tags(@backup.server, 'monthly').should eql(@backup_w)
      Backup.find_oldest_backup_amongst_younger_tags(@backup.server, 'quarterly').should eql(@backup_m)
      Backup.find_oldest_backup_amongst_younger_tags(@backup.server, 'yearly').should eql(@backup_q)
    end

    it 'should find backups no longer needed ' do
      Backup.find_backups_no_longer_needed(@backup.server.id, 'hourly', 4).should be_nil
      Backup.find_backups_no_longer_needed(@backup.server.id, 'hourly', 1)[0].should eql(@backup_h2)
      Backup.find_backups_no_longer_needed(@backup.server.id, 'hourly', 0).length.should eql(2)
      Backup.find_backups_no_longer_needed(@backup.server.id, 'hourly', 2).should be_nil
      Backup.find_backups_no_longer_needed(@backup.server.id, 'hourly', 3).should be_nil
    end
  end
end

def create_backup_with_tag(attributes, tag)
  backup = create_backup(attributes)
  backup.backup_tags << create_backup_tag({:backup => backup, :tag => tag})
  backup.save!
  Backup.find(backup.id)
end
