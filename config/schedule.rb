require 'config/environment'

def timing(bucket)
  case bucket
    when 'minute'     then 20.minutes
    when 'hourly'     then :hourly
    when 'daily'      then :daily
    when 'weekly'     then :weekly
    when 'monthly'    then :monthly
    when 'quarterly'  then 90.days
    when 'yearly'     then :yearly
  end
end

Server::FREQUENCY_BUCKETS.each do |bucket|
  every timing(bucket) do
    runner "Delayed::Job.enqueue SnapshotCreationJob.new(\"#{bucket}\")"
  end
end

every timing(Server::FREQUENCY_BUCKETS.first) do
  runner "Delayed::Job.enqueue SnapshotRemovalJob.new"
end