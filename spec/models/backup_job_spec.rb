require 'spec_helper'

describe BackupJob do
  before(:each) {
    @server = create_server({:daily => 1, :weekly => 1})
    @backup_job = BackupJob.new(@server.id, 'daily')
  }

  it 'should create a new backup' do
    @backup_job.run_backup
    Backup.find(:first).backup_tags[0].tag.should == 'daily'
  end

  it 'should add another tag' do
    @backup_job.run_backup
    Backup.find(:first).backup_tags[0].tag.should == 'daily'
    @backup_job.tag = 'weekly'
    @backup_job.run_backup
    Backup.find(:first).backup_tags.length.should eql(2)
  end
end

## Don't actually trigger any real backups
class BackupJob
  def create_backup_volume(server)
    'test vol name'
  end
  def remove_backup_volume(volume_id)
    puts 'remove fake vol '+ volume_id +' '+ (Time.now.to_s)
  end
end
