class AddHostnameToServers < ActiveRecord::Migration
  def self.up
    add_column :servers, :hostname, :string, :null => false
    change_column :servers, :system_backup_id, :string, :null => true
  end

  def self.down
    change_column :servers, :system_backup_id, :string, :null => false
    remove_column :servers, :hostname
  end
end