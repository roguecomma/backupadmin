class SnapshotEventsController < ApplicationController
  # GET /snapshot_events
  # GET /snapshot_events.xml
  def index
    @snapshot_events = SnapshotEvent.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @snapshot_events }
    end
  end

  # GET /snapshot_events/1
  # GET /snapshot_events/1.xml
  def show
    @snapshot_event = SnapshotEvent.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @snapshot_event }
    end
  end
end
