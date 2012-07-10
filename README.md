Backup Admin
============


Components
----------

Rails app - Web interface to configure backups
Delayed Job queue - Backup jobs are performed asynchronously from a queue. At least one queue process will need to be run (`rake jobs:work`)
Cron - A schedule.rb file is provided to define tasks that need to run periodically. Use the whenever gem to export this to a cron file on a server when you deploy. See https://github.com/javan/whenever


Configuration
-------------

Backup admin can be configured for your environment through environment variables. The following are required:

* AWS_ACCESS_KEY: Amazon account
* AWS_SECRET_ACCESS_KEY: Amazon secret key
* SECRET_TOKEN: A random string used by Rails to secure sessions (generate with `rake secret`)

Optional integrations may also be enabled by providing configuration for each service.

**Newrelic**

Enabled when NEWRELIC_KEY is set.

**Airbrake**

Enabled when AIRBRAKE_KEY is set. It his highly recommended that this is enabled as Backup Admin will report execution failures via Airbrake.