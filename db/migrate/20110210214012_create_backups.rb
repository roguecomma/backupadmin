class CreateBackups < ActiveRecord::Migration
  def self.up
    create_table :backups do |t|
      t.integer :server_id, :null => false
      t.date :backup_taken, :null => false
      t.string :bucket, :null => false, :limit => 10
      t.string :volume_id, :null => false, :limit => 50

      t.timestamps
    end
  end

  def self.down
    drop_table :backups
  end
end
