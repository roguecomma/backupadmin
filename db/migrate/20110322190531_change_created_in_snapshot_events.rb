class ChangeCreatedInSnapshotEvents < ActiveRecord::Migration
  def self.up
    rename_column :snapshot_events, :created, :created_at
  end

  def self.down
    rename_column :snapshot_events, :created_at, :created
  end
end