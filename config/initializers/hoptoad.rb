HoptoadNotifier.configure do |config|
  config.api_key = 'YOURKEYHERE'
end

module CustomNotifier
  def custom_notify(error_class, error_message, parameters=nil)
    HoptoadNotifier.notify(:error_class => error_class, :error_message => error_message,
         :backtrace => caller, :parameters => parameters)
  end
end

Object.send(:include, CustomNotifier)
