class SnapshotsController < ApplicationController
  inherit_resources
  belongs_to :server
  actions :index
  
  respond_to :html, :xml
end
