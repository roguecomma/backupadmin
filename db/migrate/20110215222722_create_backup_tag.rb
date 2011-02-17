class CreateBackupTag < ActiveRecord::Migration
  def self.up
    create_table :backup_tags do |t|
      t.integer :backup_id, :null => false
      t.string :tag, :null => false, :limit => 10
    end

  end

  def self.down
    drop_table :backup_tags
  end
end
