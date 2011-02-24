class CreateSnapshotEvent < ActiveRecord::Migration
  def self.up
    create_table :snapshot_events do |t|
      t.integer :server_id, :null => false
      t.string :event_type, :null => false, :limit => 25
      t.timestamp :created, :null => false
      t.text :log, :null => false
    end
  end

  def self.down
    drop_table :snapshot_events
  end
end
