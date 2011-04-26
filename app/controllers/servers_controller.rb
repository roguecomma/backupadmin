class ServersController < ApplicationController
  inherit_resources
  respond_to :html, :xml

  def seed
    server = Server.find(params[:id])
    server.seed

    # Possibly a better way of doing this
    @servers = Server.all
    render :index
  end
end
