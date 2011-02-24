class CreateServers < ActiveRecord::Migration
  def self.up
    create_table :servers do |t|
      t.string :name, :null => false
      t.string :elastic_ip, :null => false
      t.string :mount_point, :null => false
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
