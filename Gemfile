source 'http://rubygems.org'

gem 'rails', '3.0.3', :require => %w(action_controller active_record active_support)
gem 'will_paginate', "~> 3.0.pre2"

gem 'mysql', '~> 2.8.0'
gem 'delayed_job', '2.1.4.exp1'
gem 'fog', '~> 0.7', '>= 0.7.2'
# gem 'fog', :path => '../fog'
gem 'flutie' # Default styling
gem 'haml' # SCSS support
gem 'formtastic'
gem 'inherited_resources'
gem 'has_scope'
gem 'whenever'

gem 'devise'

gem 'airbrake'
gem 'newrelic_rpm'

group :test, :development do
  gem 'rspec', '>= 2.5'
  gem 'rspec-rails', '>= 2.5'
  gem 'fakeweb'
  gem 'timecop'
  gem 'shoulda'
  gem 'autotest'
end

# Gems that won't install right on linux.  use: bundle install --without darwin
group :darwin do
  gem 'autotest-fsevent'
end