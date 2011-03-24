class SnapshotRemovalJob
  def perform
    Server.active.each { |server| cycle_through_buckets(server) }
  end

  def cycle_through_buckets(server)
    snapshots = Snapshot.find_snapshots_for_server(server)
    Server::FREQUENCY_BUCKETS.each { |frequency_bucket|
      remove_unneeded_snapshots(server, snapshots, frequency_bucket, server.get_number_allowed(frequency_bucket))
    }
  end

  def remove_unneeded_snapshots(server, snapshots, frequency_bucket, number_allowed)
    snapshots = Snapshot.filter_snapshots_for_buckets_sort_by_age(snapshots, [frequency_bucket])
    snapshots = snapshots && snapshots.length > number_allowed ? snapshots.slice(0, snapshots.length - number_allowed) : nil
    snapshots.each {|snapshot|
      if (Snapshot.get_frequency_buckets(snapshot).length == 1)
        snapshot.destroy
      else
        snapshot.remove_frequency_bucket(frequency_bucket)
      end
    } if (snapshots)
  end
end
