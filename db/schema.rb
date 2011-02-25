# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110222200953) do

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "servers", :force => true do |t|
    t.string  "name",                              :null => false
    t.string  "elastic_ip",                        :null => false
    t.string  "ssh_user",    :default => "root",   :null => false
    t.string  "mount_point",                       :null => false
    t.string  "state",       :default => "active", :null => false
    t.integer "minute",      :default => 0,        :null => false
    t.integer "hourly",      :default => 0,        :null => false
    t.integer "daily",       :default => 0,        :null => false
    t.integer "weekly",      :default => 0,        :null => false
    t.integer "monthly",     :default => 0,        :null => false
    t.integer "quarterly",   :default => 0,        :null => false
    t.integer "yearly",      :default => 0,        :null => false
  end

  create_table "snapshot_events", :force => true do |t|
    t.integer  "server_id",                :null => false
    t.string   "event_type", :limit => 25, :null => false
    t.datetime "created",                  :null => false
    t.text     "log",                      :null => false
  end

end
