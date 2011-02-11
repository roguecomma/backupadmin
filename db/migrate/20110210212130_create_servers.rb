class CreateServers < ActiveRecord::Migration
  def self.up
    create_table :servers do |t|
      t.string :name, :null => false
      t.string :dns, :null => false
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
