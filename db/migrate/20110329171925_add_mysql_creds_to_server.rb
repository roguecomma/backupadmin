class AddMysqlCredsToServer < ActiveRecord::Migration
  def self.up
    add_column :servers, :mysql_user, :string
    add_column :servers, :mysql_password, :string
  end

  def self.down
    remove_column :servers, :mysql_user
    remove_column :servers, :mysql_password
  end
end
