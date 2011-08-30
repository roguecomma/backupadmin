class AddServerSnapshotType < ActiveRecord::Migration
  def self.up
    add_column :servers, :snapshot_type, :string
    Server.update_all "snapshot_type = 'mysql'", "snapshot_type is null"
  end

  def self.down
    remove_column :servers, :snapshot_type, :string
  end
end
