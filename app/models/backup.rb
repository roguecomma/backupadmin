class Backup < ActiveRecord::Base
  belongs_to :server
  has_many :backup_tags, :dependent => :destroy

  def self.find_oldest_backup_amongst_younger_tags(server, tag)
    Backup.select('backups.*').joins(:backup_tags).order("snapshot_started asc").where('backup_tags.tag in (?)', Server.get_younger_tags(tag)).first
  end

  def self.find_backups_no_longer_needed(server_id, tag, number_allowed)
    backups = Backup.select('backups.*').joins(:backup_tags).order("snapshot_started asc").where('backups.server_id = ? and backup_tags.tag = ?', server_id, tag)
    return backups && backups.length > number_allowed ? backups.slice(0, backups.length - number_allowed) : nil
  end
end
