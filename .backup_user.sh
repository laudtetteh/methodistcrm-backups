#!/bin/sh
# ssh into client server and create compressed backup
# This script only works if the current user already
# has their public key included inside the client's ~.ssh/authorized_keys
# This script only works under these conditions:
# 1. The functions "getSite()" and "backup()" have already been added
# as aliases in .bashrc or elsewhere and pointed to this script
# 2. All the necessary client credentials have been included in that "getSite()" function
# 3. All the public ssh key on the local server - server holding the backup directorys - has
# been included inside each clients ~.ssh/authorized_keys for automatated ssh access
# (https://serverfault.com/questions/241588/how-to-automate-ssh-login-with-password)
# 4. A hidden config file (.db_config.cnf) has been placed in root dir for storing mysql info
# 5. A hidden log file (.backup_log.txt) has been placed in root dir for storing log

# Define a timestamp function
timestamp() {
  date +%Y-%m-%d-%H:%M
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
            echo new "\"$1\"" directory created! >> .backup_log.txt
        else
            echo could not create new "\"$1\"" directory! >> .backup_log.txt
        fi

    else
        echo "\"$1\"" directory already exists! >> .backup_log.txt
    fi
}

function create() {
    cd ~/$2

    echo compressing uploads and db backup from "\"$1\"" directory...
    # place config file in root dir for storing mysql info
    #https://stackoverflow.com/a/22933056
    mysqldump --defaults-extra-file=./.db_config.cnf $3 > "$1"_database.sql
    zip -r "$1".zip "$1"_database.sql uploads/*

    if [ $? -eq 0 ]; then
        echo ...compression of assets complete! >> .backup_log.txt
    else
        echo ...ERROR: could not compress assets! >> .backup_log.txt
    fi
}

function move() {
    # move the newly-created backup
    echo checking for current "'$1'" backup...
    # If no backup is found with the same name
    if [ ! -f ~/mcrm_backups/"$1"/"$5" ]; then
        # Then indicate in the backup_log.txt file at the app root
        echo ...no current "'$1'" backup. >> .backup_log.txt
        echo Moving new backup now...
        mv ~/$2/"$1".zip ~/mcrm_backups/"$1"/"$5"

    elif [ -f ~/mcrm_backups/"$1"/"$5" ]; then
        # Otherwise, if a backup exists with the same bame
        echo ...current backup already exists! >> .backup_log.txt

        if [ ! -f ~/mcrm_backups/"$1"/"$5".temp ]; then
            # Then temporarily rename that existing archive
            echo temporarily renaming current "$1" backup...
            mv ~/mcrm_backups/"$1"/"$5" ~/mcrm_backups/"$1"/"$5".temp
            echo ...renaming complete!

        fi

        # Move newly-created backup file into the appropriate folder
        echo now moving fresh "'$1'" backup to backup directory...
        mv ~/$2/"$1".zip ~/mcrm_backups/"$1"/"$5"

        if [ -f ~/mcrm_backups/"$1"/"$5" ]; then

            echo ...new "'$1'" backup successfully moved!
            # Remove temporarily renamed archive from line 72 above
            if [ -f ~/mcrm_backups/"$1"/"$5".temp ]; then

                echo deleting renamed temp backup, if one exists...
                rm -rf ~/mcrm_backups/"$1"/"$5".temp
                echo ...temp backup deleted!

            fi
        fi
    fi

    if [ $? -eq 0 ]; then
        # Log result to backup_log.txt
        echo ...move complete! >> .backup_log.txt
    else
        echo ERROR: could not move backup! >> .backup_log.txt
    fi
}

function cleanup() {
    # ssh in and delete the db dump
    echo now cleaning up in "$1" site directory...
    cd ~/$2 \
    # Remove that MySQL dump that was created for the backup
    && rm -rf "$1"_database.sql \

    if [ $? -eq 0 ]; then
        echo ...cleanup complete! >> .backup_log.txt
    else
        echo ERROR: could not complete cleanup in site directory! >> .backup_log.txt
    fi
}

function toDb() {
    cd ~/$2
    # place config file in root dir for storing mysql info
    #https://stackoverflow.com/a/22933056
    # Read .db_config.cnf file for DB credentials, log into DB and record this backup instance
    mysql --defaults-extra-file=./.db_config.cnf $3 -e "INSERT INTO backups (date_time, archive_name, description, creator_user_id, backup_id, created_by, modified_by, created_at, updated_at) VALUES ('$4', '$5', '$6', '$7', '$8', '$7', '$7', '$9', '$9')";
}

function runAll() {
    # Record Backup Started in .backup_log.txt file in app root directory
    printf "........."\"$1\"" Backup Started at $timestamp.........\n" >> .backup_log.txt
    # call the "mkcd" function, and pass directory name
    mkcd $1 $2 $3 "$4" $5 "$6" $7 $8 "$9"
    # call the "create" function
    create $1 $2 $3 "$4" $5 "$6" $7 $8 "$9"
    # call the "move" function
    move $1 $2 $3 "$4" $5 "$6" $7 $8 "$9"
    # call the "toDb" function
    toDb $1 $2 $3 "$4" $5 "$6" $7 $8 "$9"
    # call the "cleanup" function
    cleanup $1 $2 $3 "$4" $5 "$6" $7 $8 "$9"

    if [ $? -eq 0 ]; then
        echo BACKUP COMPLETE: "'$1'"! >> .backup_log.txt
        echo BACKUP COMPLETE: "'$1'"!
    else
        echo BACKUP FAILED: "'$1'"! >> .backup_log.txt
        echo BACKUP FAILED: "'$1'"!
    fi
    # Record success in .backup_log.txt file in app root directory
    printf "........................|Backup Ended|........................\n\n" >> .backup_log.txt

    exit ; bash
}

function x(){
    echo "$1" | sed -r 's/[%%]+/ /g'
}

getMcrmUploads() {
    staging=( "staging" "webapps/methodistcrm_staging" "methodistcrm_staging" )
    production=( "production" "webapps/methodistcrm_app" "methodistcrm_app" )

    if [ $1 = "staging" ]; then
        echo "${staging[@]}"
    elif [ $1 = "production" ]; then
        echo "${production[@]}"
    fi
}

run_backup() {
    runAll $(getMcrmUploads $1) "$(x $2)" $3 "$(x $4)" $5 "$6" "$(x $7)"
}

# $1 == $app_env_sh
# $2 == $date_time_db
# $3 == $archive_name_sh
# $4 == $description_sh
# $5 == $creator_user_id_sh
# "$6" == $backup_id_sh
# $7== $date_cr_mod_db

run_backup $1 $2 $3 $4 $5 "$6" $7
