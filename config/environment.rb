# Load the rails application
require File.expand_path('../application', __FILE__)

# Used by dj
require 'ostruct'
::AppConfig = OpenStruct.new

# Initialize the rails application
Backupadmin::Application.initialize!
