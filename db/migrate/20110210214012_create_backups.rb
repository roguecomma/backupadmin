class CreateBackups < ActiveRecord::Migration
  def self.up
    create_table :backups do |t|
      t.integer :server_id, :null => false
      t.timestamp :snapshot_started, :null => false
      t.timestamp :snapshot_finished
      t.string :volume_id, :null => false, :limit => 50
    end
  end

  def self.down
    drop_table :backups
  end
end
