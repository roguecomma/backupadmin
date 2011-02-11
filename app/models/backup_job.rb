class BackupJob < Struct.new(:server_id, :bucket)
  def perform
    puts("BackupJob-> server_id="+ (self.server_id.to_s) +", bucket="+ (self.bucket.to_s) +", time="+ (Time.now.to_s))
    server = Server.find(server_id)
    if server.is_highest_frequency_bucket?(bucket)
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.bucket.to_s) +"] new backup requested")
    else
      puts("BackupJob-> ["+ (self.server_id.to_s) +", "+ (self.bucket.to_s) +"] renaming a backup")
    end
  end
end
