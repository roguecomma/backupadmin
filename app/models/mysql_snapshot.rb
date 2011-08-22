require 'mysql'

class MysqlSnapshot < Snapshot

  class << self


    def suspend_activity_and_snapshot(server, frequency_bucket)
      snap = nil
      table_lock = false
      xfs_lock = false
      mysql = Mysql.init()

      # Port forwarding over ssh won't work unless we put this code in a sep thread
      #ssh.forward.local(1234, server.ip, 3306)
      #ssh.loop { true }

      begin
        mysql.connect(server.ip, server.mysql_user, server.mysql_password)
        mysql.query("FLUSH TABLES WITH READ LOCK")
        table_lock = true
        server.ssh_exec("xfs_freeze -f #{server.mount_point}")
        xfs_lock = true

        # here we kick off the actual snapshot
        snap = super

        server.ssh_exec("xfs_freeze -u #{server.mount_point}")
        xfs_lock = false
        mysql.query("UNLOCK TABLES")
        table_lock = false
      ensure
        swallow_errors { server.ssh_exec("xfs_freeze -u #{server.mount_point}") } if xfs_lock
        swallow_errors { mysql.query("UNLOCK TABLES") } if table_lock
        mysql.close()
      end
      snap
    end


  end

end
