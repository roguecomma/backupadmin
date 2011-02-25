class SnapshotRemovalJob
  def perform
    Server.find(:all).each { |server|
      if server.is_active?
        cycle_through_buckets(server)
      end
    }
  end

  def cycle_through_buckets(server)
    snapshots = Snapshot.find_snapshots_for_server(server)
    server.frequency_buckets.each { |frequency_bucket|
      remove_unneeded_snapshots(snapshots, frequency_bucket, server.get_number_allowed(frequency_bucket))
    }
  end

  def remove_unneeded_snapshots(snapshots, frequency_bucket, number_allowed)
    snapshots = Snapshot.filter_snapshots_for_buckets_sort_by_age(snapshots, [frequency_bucket])
    snapshots = snapshots && snapshots.length > number_allowed ? snapshots.slice(0, snapshots.length - number_allowed) : nil
    snapshots.each {|snapshot|
      if (Snapshot.get_frequency_buckets(snapshot).length == 1)
        Snapshot.remove_snapshot(snapshot)
      else
        Snapshot.remove_from_frequency_bucket(snapshot, frequency_bucket)
      end
    } if (snapshots)
  end
end
