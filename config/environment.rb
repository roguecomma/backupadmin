# Load the rails application
require File.expand_path('../application', __FILE__)

# Used by dj
require 'ostruct'
::AppConfig = OpenStruct.new

# Initialize the rails application
Backupadmin::Application.initialize!

::AppConfig.ec2 = YAML::load(IO.read("config/amazon_ec2.yml"))[Rails.env.to_s]
