class BackupJob < Struct.new(:server_id, :tag)
  def perform
    run_backup
    remove_unneeded_backups
  end

  def run_backup
    puts("BackupJob-> server_id="+ (self.server_id.to_s) +", tag="+ (self.tag.to_s) +", time="+ (Time.now.to_s))
    server = Server.find(server_id)
    if server.is_highest_frequency_tag?(tag)
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.tag.to_s) +"] new backup requested")
      backup = Backup.new
      backup.server = server
      backup.backup_tags = [BackupTag.new]
      backup.backup_tags[0].tag = tag
      backup.snapshot_started = Time.now
      backup.volume_id = create_backup_volume(server)
      backup.save!
    else
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.tag.to_s) +"] renaming a backup")
      backup = Backup.find_oldest_backup_amongst_younger_tags(server, tag)
      if (backup)
        backup_tag = BackupTag.new
        backup_tag.tag = tag
        backup.backup_tags << backup_tag
        backup.save!
      end
    end
  end

  def remove_unneeded_backups
    server = Server.find(server_id)
    backups = Backup.find_backups_no_longer_needed(server_id, tag, server.get_number_allowed(tag))
    if (backups)
      backups.each {|backup|
        if (backup.backup_tags.length == 1)
          remove_backup_volume(backup.volume_id) if (backup.volume_id)
          backup.delete!
        else
          backup.backup_tags.delete_if {|bt| bt.tag == tag}
          backup.save!
        end
      }
    end
  end

  # Note: Don't forget to implement this
  def create_backup_volume(server)
    'fake vol '+ (Time.now.to_s)
  end

  # Note: Don't forget to implement this
  def remove_backup_volume(volume_id)
    puts 'this going away -- remove fake vol '+ volume_id +' '+ (Time.now.to_s)
  end
end
