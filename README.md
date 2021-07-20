# MethodistCRM Backup Tool
Snippets from a backup tool that I wrote for the MethodistCRM Laravel app. It includes 2 shell scripts, some PHP, a Database config file, and a log file.

## Two different methods
Backups are created in 2 ways: 

### 1. User-initiated 
A user-submitted form triggers the controller action that executes the _.backup_user.sh_ shell script.


### 2. Automated (Cron job)
I wrote 2 cron jobs at server level that run the _.backup_cron.sh_ script once every 2 hours for the Production app and every 4 hours for the Staging app, like so: 

`0 2 * * * $HOME/.backup_cron.sh staging >> ~/logs/user/cron-mcrm_staging.log 2>&1 | mail -s "Staging Backup Started - MethodistCRM" -S from=dev@methodistcrm.com laud@studiotenfour.com`

`0 */4 * * * $HOME/.backup_cron.sh production >> ~/logs/user/cron-mcrm_production.log 2>&1 | mail -s "Production Backup Started - MethodistCRM" -S from=dev@methodistcrm.com laud@studiotenfour.com`



## How it works
For both the user-initiated script and the cron-initiated script, here are the steps involved:

1. The script looks to see if a backup directory exists for the current environment (Production/Staging/Local), and creates one if none is found.
2. Next, it logs into MySQL and creates a database dump inside the root directory, and names it `some_time_stamp.sql`
3. It also compresses all files from Laravel's /uploads directory, along with the db dump from step 2 above, then places the zip file in the root directory and names it `env_name_some_timestamp.zip`. Backups names are simply a timestamp prefixed by the app environment - Production/Staging/Local
4. Next, it checks for an existing backup by the same name as the one we just created
5. If one exists, it temporarily renames it, moves the newly-created backup in its place. If successful, it deletes the old, renamed backup.
6. If none is found, it simply moves the new backup into the appropriate directory from step 1.
7. Finally, it removes the db dump created in step 2 from the root directory, then inserts a row for the successful backup into the `backups` table

