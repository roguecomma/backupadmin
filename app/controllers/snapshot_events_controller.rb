class SnapshotEventsController < ApplicationController
  inherit_resources
  actions :index, :show
  respond_to :html, :xml
  
  has_scope :for_server_id, :only => :index
  
  private
  
    def collection
      @snapshot_events = end_of_association_chain.join_server
    end
    
end
