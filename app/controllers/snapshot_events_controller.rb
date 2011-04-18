class SnapshotEventsController < ApplicationController
  inherit_resources
  actions :index, :show
  respond_to :html, :xml
  
  has_scope :only => :index
  
  def index
    @snapshot_events = SnapshotEvent.for_server_id(params[:server_id]).join_server.paginate(:page => params[:page], :per_page => 100)
  end
end
