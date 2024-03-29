module Factory
  
  class << self  
    # Builds helper methods for generating ActiveRecord instances during tests.
    def build(model, name = model.to_s.underscore.gsub(/[^A-Za-z0-9_]/, '_'), &block)
      raise ArgumentError, "#{model} builder is already defined" if method_defined?("#{name}_attributes")
      
      define_method("#{name}_attributes", block)
      define_method("valid_#{name}_attributes") {|*args| valid_attributes_for(model, name, *args)}
      define_method("new_#{name}")              {|*args| new_record(model, name, *args)}
      define_method("create_#{name}")           {|*args| create_record(model, name, *args)}
    end
    
    @@counters = {}
    
    def counter(name)
      @@counters[name] ||= 0
      @@counters[name] += 1
    end
  end
  
  # Generates a collection of attributes that will create a valid instance of
  # the model
  def valid_attributes_for(model, name = model.to_s.underscore, attributes = {})
    send("#{name}_attributes", attributes)
    attributes
  end
  
  # Generates a new record for the given model
  def new_record(model, *args)
    attributes = valid_attributes_for(model, *args)
    
    # Generate the record with the attributes that were just defined
    record = model.new(attributes)
    
    # Some of the attributes may be inaccessible, so their setters are used
    # instead. This can happen of attr_accessible or attr_protected are used
    # within model definitions
    attributes.each do |attr, value|
      record.send("#{attr}=", value) if attr == :id || model.accessible_attributes && !model.accessible_attributes.include?(attr) || model.protected_attributes && model.protected_attributes.include?(attr)
    end if model < ActiveRecord::Base
    
    record
  end
  
  # Generates and save a new record for the given model. The record will be
  # reloaded after being saved to ensure that any associations are fresh when
  # being used within the test
  def create_record(model, *args)
    record = new_record(model, *args) 
    record.save!
    record.reload
    record
  end

  build Server do |attributes|
    attributes.reverse_merge!(
      :name => 'test-server',
      :mount_point => '/volfake',
      :block_device => '/dev/sdfake',
      :snapshot_type => Server::SNAPSHOT_TYPES[0],
      :hostname => "server-#{Factory.counter('server')}.local"
    )
    attributes
  end
  
  class Blank < OpenStruct
    
    private 
    
      def self._blank_slate(*args)
        args.each do |method|
          define_method(method) do 
            method_missing(method)
          end
        end
      end
    
    _blank_slate :id, :id=
  end
end

def create_fake_snapshot(attributes)
  attributes[:created_at] = Time.now unless attributes.include?(:created_at)
  attributes[:tags] = {Snapshot.tag_name('daily') => nil, Server::BACKUP_ID_TAG => 'some.elastic.ip.com'} unless attributes.include?(:tags)
  attributes[:id] = 'snap-fake-747473' unless attributes.include?(:id)
  Factory::Blank.new(attributes)
end

def create_snapshot(attributes = {})
  server = attributes[:server]
  volume = attributes[:volume]
  raise ":server and :volume are required attributes" unless server && volume
  
  Snapshot.new(server, AWS.snapshots.create(:volume_id => volume.id).reload).tap do |snap|
    AWS.create_tags(snap.id, {Server::BACKUP_ID_TAG => server.system_backup_id}.merge(attributes[:tags]))
  end
end

def create_volume(attributes = {})
  AWS.volumes.create(attributes.reverse_merge(:availability_zone => 'us-east-1d', :size => '100G'))
end