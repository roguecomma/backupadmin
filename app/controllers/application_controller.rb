class ApplicationController < ActionController::Base
  include SslRequirement

  protect_from_forgery
  #always require SSL for everything.
  ssl_required

  before_filter :authenticate_user!


end
