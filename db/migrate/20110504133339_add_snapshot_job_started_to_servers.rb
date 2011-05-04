class AddSnapshotJobStartedToServers < ActiveRecord::Migration
  def self.up
    add_column :servers, :snapshot_job_started, :datetime
  end

  def self.down
    remove_column :servers, :snapshot_job_started
  end
end