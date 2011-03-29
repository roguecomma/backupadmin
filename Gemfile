source 'http://rubygems.org'

gem 'rails', '3.0.3', :require => %w(action_controller active_record active_support)

gem 'mysql', '~> 2.8.0'
gem 'delayed_job', '2.1.4.exp1'
#gem 'fog', '~> 0.5'
gem 'fog', :path => '../fog'
#gem 'fog', :git => 'git@github.com:geemus/fog.git'
gem 'flutie' # Default styling
gem 'haml' # SCSS support
gem 'formtastic'
gem 'inherited_resources'
gem 'has_scope'
gem 'whenever'

gem 'hoptoad_notifier'
gem 'newrelic_rpm'

group :deploy do
  gem 'capistrano'
  gem 'capistrano-ext'
end

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