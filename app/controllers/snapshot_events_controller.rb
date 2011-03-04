class SnapshotEventsController < ApplicationController
  def index
    @snapshot_events = SnapshotEvent.join_server
    @snapshot_events = @snapshot_events.find_all_by_server_id(params[:server_id]) if params[:server_id]

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @snapshot_events }
    end
  end

  def show
    @snapshot_event = SnapshotEvent.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @snapshot_event }
    end
  end
end
