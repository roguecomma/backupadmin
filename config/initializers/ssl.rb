ActionController::Base.class_eval do
  include SslRequirement

  # Only allows ssl to be required if configured for the environment
  def ssl_required_with_app_config?
    ENV['RAILS_ENV'] == 'production' && (self.class.read_inheritable_attribute(:ssl_required_actions) == [] || ssl_required_without_app_config?)
  end
  alias_method_chain :ssl_required?, :app_config

  # Only allows ssl to be allowed if configured for the environment
  def ssl_allowed_with_app_config?
    !ssl_required? && AppConfig.use_ssl && (self.class.read_inheritable_attribute(:ssl_allowed_actions) == [] || ssl_allowed_without_app_config?)
  end
  alias_method_chain :ssl_allowed?, :app_config
end
