class SnapshotsController < ApplicationController
  def index
    @server = Server.find(params[:server_id])
    @snapshots = Snapshot.find_snapshots_for_server(@server)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @snapshots }
    end
  end

  def show
    @snapshot = Snapshot.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @snapshot }
    end
  end
end
