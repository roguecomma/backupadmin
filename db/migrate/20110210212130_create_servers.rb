class CreateServers < ActiveRecord::Migration
  def self.up
    create_table :servers do |t|
      t.string :name, :null => false
      t.string :system_backup_id, :null => false, :limit => 64
      t.string :ssh_user, :null => false, :default => 'root'
      t.string :block_device, :null => false, :limit => 15
      t.string :mount_point, :null => false, :limit => 15
      t.string :state, :null => false, :default => 'active'
      t.integer :minute, :null => false, :default => 0
      t.integer :hourly, :null => false, :default => 0
      t.integer :daily, :null => false, :default => 0
      t.integer :weekly, :null => false, :default => 0
      t.integer :monthly, :null => false, :default => 0
      t.integer :quarterly, :null => false, :default => 0
      t.integer :yearly, :null => false, :default => 0
    end
  end

  def self.down
    drop_table :servers
  end
end
