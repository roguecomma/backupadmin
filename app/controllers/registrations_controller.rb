class RegistrationsController < Devise::RegistrationsController
  def update
    # do something different here
  end

  def new
    # not a standard action
    # deactivate code here
  end

  def create

  end

  def destroy

  end
end