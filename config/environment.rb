# Load the rails application
require File.expand_path('../application', __FILE__)

# Used by dj
require 'ostruct'
::AppConfig = OpenStruct.new

# Initialize the rails application
Backupadmin::Application.initialize!

::AppConfig.ec2 = YAML::load(IO.read("config/amazon_ec2.yml"))[Rails.env.to_s]

# Allow RPM to instrument garbage collection
GC.enable_stats if GC.respond_to?(:enable_stats)

if GC.respond_to?(:copy_on_write_friendly=)
  # Turn this on so we get better shared memory usage when forking
  GC.copy_on_write_friendly = true
end
