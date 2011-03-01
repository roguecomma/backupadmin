class CreateServers < ActiveRecord::Migration
  def self.up
    create_table :servers do |t|
      t.string :name, :null => false
      t.string :system_backup_id, :null => false, :limit => 64
      t.string :ssh_user, :null => false, :default => 'root'
      t.string :block_device, :null => false, :limit => 15, :default => '/dev/sdh'
      t.string :mount_point, :null => false, :limit => 15, :default => '/vol'
      t.string :state, :null => false, :default => 'active'
      t.integer :minute, :null => false, :default => 3
      t.integer :hourly, :null => false, :default => 5
      t.integer :daily, :null => false, :default => 7
      t.integer :weekly, :null => false, :default => 4
      t.integer :monthly, :null => false, :default => 3
      t.integer :quarterly, :null => false, :default => 4
      t.integer :yearly, :null => false, :default => 7
    end
  end

  def self.down
    drop_table :servers
  end
end
