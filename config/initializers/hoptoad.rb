HoptoadNotifier.configure do |config|
  config.api_key = 'YOURKEYHERE'
  config.params_filters << "ssh_key"
  config.params_filters << "mysql_password"
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
    HoptoadNotifier.notify(options.merge(:parameters => parameters))
  end
end