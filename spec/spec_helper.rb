# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'

# Required environment configuration
%w(SECRET_TOKEN AWS_ACCESS_KEY AWS_SECRET_ACCESS_KEY).each do |k|
  ENV[k] = k.downcase.tr('_','-')
end

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'factory'
require 'fakeweb'
require 'timecop'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  include Factory

  config.use_transactional_fixtures = true

  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec
  
  FakeWeb.allow_net_connect = false
  
  config.before(:each) do
    # Reset fog mock data
    AWS.reset_data
  end
end
