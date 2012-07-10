if ENV['AIRBRAKE_KEY']
  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_KEY']
    config.params_filters << "ssh_key"
    config.params_filters << "mysql_password"
  end
end

module CustomNotifier
  def self.notify(exception, parameters=nil)
    options = {}
    if exception.instance_of?(Hash)
      options = exception.merge(:backtrace => caller)
    else
      options = {
        :error_class => exception.class, :error_message => exception.message,
        :backtrace => exception.backtrace
      }
    end
    Airbrake.notify(options.merge(:parameters => parameters))
  end
end