class SnapshotRemovalJob
  def perform
    Server.active.each { |server| cycle_through_buckets(server) }
  end

  def cycle_through_buckets(server)
    Server::FREQUENCY_BUCKETS.each { |frequency_bucket|
      remove_unneeded_snapshots(server, frequency_bucket, server.get_number_allowed(frequency_bucket))
    }
  end

  def remove_unneeded_snapshots(server, frequency_bucket, number_allowed)
    snapshots = server.snapshots_for_frequency_buckets(frequency_bucket)
    prune_index = snapshots.length - number_allowed
    unless prune_index <= 0
      prune_snapshots = snapshots.slice(0, prune_index)
      prune_snapshots.each do |snapshot|
        if (snapshot.frequency_buckets.length == 1)
          snapshot.destroy
        else
          snapshot.remove_frequency_bucket(frequency_bucket)
        end
      end
    end
  end
end
