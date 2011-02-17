class Backup < ActiveRecord::Base
  belongs_to :server
  has_many :backup_tags

  def self.find_oldest_backup_amongst_younger_tags(server, tag)
    Backup.select('backups.*').joins(:backup_tags).order("snapshot_started asc").where('backup_tags.tag in (?)', Server.get_younger_tags(tag)).first
  end
end
