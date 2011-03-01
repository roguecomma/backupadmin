class SnapshotCreationJob < Struct.new(:frequency_bucket)
  def perform
    Server.find(:all).each { |server|
      run(server) if server.is_active?
    }
  end

  def run(server)
    if server.is_highest_frequency_bucket?(frequency_bucket)
      Snapshot.take_snapshot(server, frequency_bucket)
    else
      snapshot = Snapshot.find_oldest_snapshot_in_higher_frequency_buckets(server, frequency_bucket)
      if (snapshot)
        Snapshot.add_to_frequency_bucket(server, snapshot, frequency_bucket)
      end
    end
  end
end
