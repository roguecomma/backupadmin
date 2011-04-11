class AddSshKeyToServers < ActiveRecord::Migration
  def self.up
    add_column :servers, :ssh_key, :string, :limit => 4000
  end

  def self.down
    remove_column :servers, :ssh_key
  end
end
