# MethodistCRM Backup Tool
Snippets from a backup tool that I wrote for the MethodistCRM Laravel app. It includes 2 shell scripts, some PHP, a Database config file, and a log file.

## How it works
Backups are created in 2 ways: 

### User-initiated 
A user-submitted form triggers the controller action that executes the _.backup_user.sh_ shell script.


### Cron job
Two automated taskrunners at server level. The cron job runs the _.backup_cron.sh_ script runs once every 2 hours for the Production app and every 4 hours for the Staging app, like so: 

`0 2 * * * $HOME/.backup_cron.sh staging >> ~/logs/user/cron-mcrm_staging.log 2>&1 | mail -s "Staging Backup Started - MethodistCRM" -S from=dev@methodistcrm.com laud@studiotenfour.com`

`0 */4 * * * $HOME/.backup_cron.sh production >> ~/logs/user/cron-mcrm_production.log 2>&1 | mail -s "Production Backup Started - MethodistCRM" -S from=dev@methodistcrm.com laud@studiotenfour.com`


