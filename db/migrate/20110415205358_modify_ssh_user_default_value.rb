class ModifySshUserDefaultValue < ActiveRecord::Migration
  def self.up
    change_column :servers, :ssh_user, :string, :null => false, :default => 'dbbackup'
  end

  def self.down
    change_column :servers, :ssh_user, :string, :null => false, :default => 'root'
  end
end
