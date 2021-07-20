#!/bin/sh
# ssh into client server and create compressed backup
# This script only works if the current user already
# has their public key included inside the client's ~.ssh/authorized_keys
# This script only works under these conditions:
# 1. All the necessary client credentials have been included in the db_config.cnf file in the same location as this script
# 2. All the public ssh key on the local server - server holding the backup directorys - has
# been included inside each clients ~.ssh/authorized_keys for automatated ssh access
# (https://serverfault.com/questions/241588/how-to-automate-ssh-login-with-password)
# 3. The following cron job has been added to the server's crontab
#`0 */4 * * * $HOME/.backup_mcrm.sh production >> ~/logs/user/cron-mcrm_production.log 2>&1 | mail -s "Production Backup Started - MethodistCRM" -S from=dev@methodistcrm.com laud@studiotenfour.com`


# Define a timestamp function
timestamp() {
  date +%Y_%m_%d_%H_%M_%S
}

# declare variables to be used for this backup session
# these depend on what site name is appended to the "backup" command
declare -r timestamp=$(timestamp)

function mkcd() {
    # create a backup directory for this client, if none exists
    if [ ! -d ~/mcrm_backups/"$1" ]; then
        echo mcrm backup directory does not exist. Creating one now...
        mkdir -p -- ~/mcrm_backups/"$1"

        if [ $? -eq 0 ]; then
            echo new "\"$1\"" directory created!
        else
            echo could not create new "\"$1\"" directory!
        fi

    else
        echo "\"$1\"" directory already exists!
    fi
}

function create() {

    # echo site_directory is "\"$2\""
    # ssh in and create the backup of files and db
    echo compressing uploads and db backup from "\"$1\"" directory...

    cd ~/$2 \
    && mysqldump --password=$5 --user=$4 $3 > "$1"_database.sql \
    && zip -r "$1".zip "$1"_database.sql uploads/* \

    if [ $? -eq 0 ]; then
        echo ...compression of assets complete!
    else
        echo ...ERROR: could not compress assets!
    fi
}

function move() {
    # move the newly-created backup
    echo checking for current "'$1'" backup...

    if [ ! -f ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip ]; then

        echo ...no current "'$1'" backup.
        echo Moving new backup now...
        mv ~/$2/"$1".zip ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip

    elif [ -f ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip ]; then

        echo ...current backup already exists!

        if [ ! -f ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip.temp ]; then

            echo temporarily renaming current "$1" backup...
            mv ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip.temp
            echo ...renaming complete!

        fi

        echo now moving fresh "'$1'" backup to backup directory...
        mv ~/$2/"$1".zip ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip

        if [ -f ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip ]; then

            echo ...new "'$1'" backup successfully moved!

            if [ -f ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip.temp ]; then

                echo deleting renamed temp backup, if one exists...
                rm -rf ~/mcrm_backups/"$1"/"$1"_"$timestamp".zip.temp
                echo ...temp backup deleted!

            fi
        fi
    fi

    if [ $? -eq 0 ]; then
        echo ...move complete!
    else
        echo ERROR: could not move backup!
    fi
}

function cleanup() {
    # ssh in and delete the db dump
    echo now cleaning up in "$1" site directory...
    cd ~/$2 \
    && rm -rf "$1"_database.sql \

    if [ $? -eq 0 ]; then
        echo ...cleanup complete!
    else
        echo ERROR: could not complete cleanup in site directory!
    fi
}

function runAll(){
    # call the "mkcd" function, and pass directory name
    mkcd $1 $2 $3 $4 $5
    # call the "create" function
    create $1 $2 $3 $4 $5
    # # call the "move" function
    move $1 $2 $3 $4 $5
    # #  call the "cleanup" function
    cleanup $1 $2 $3 $4 $5

    if [ $? -eq 0 ]; then
        echo BACKUP COMPLETE: "'$1'"!
    else
        echo BACKUP FAILED: "'$1'"!
    fi

    exit ; bash
}

getMcrmUploads() {
    staging=( "staging" "webapps/methodistcrm_staging" "methodistcrm_staging" "xxxxxxxxx" "xxxxxxxxx" )
    production=( "production" "webapps/methodistcrm_app" "methodistcrm_app" "xxxxxxxxx" "xxxxxxxxx" )

    if [ $1 = "staging" ]; then
        echo "${staging[@]}"
    elif [ $1 = "production" ]; then
        echo "${production[@]}"
    fi
}

run_backup() {
    runAll $(getMcrmUploads $1)
}

run_backup $1
