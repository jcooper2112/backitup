#!/bin/bash

# backup folder name format will be backup.YYYYMMDD_HHMMSS
# source & dest paths should be defined here along with 'oldestkeeper'
srcpath="/raid/"
destpath="/backup_A/"
backupage="-30 days"

# generate new foldername
newfn=backup.$(date +%Y-%m-%d_%H%M%S)
#echo "New folder name is: "$newfn

# check if raid is mounted:
if mountpoint -q $srcpath; then
#   mounted, do nothing
    :
else
#   not mounted, try once to mount raid
    echo "RAID not mounted; trying to mount..."
    mount /dev/md0 $srcpath
fi

# check again if raid is mounted
if mountpoint -q $srcpath; then
    echo "RAID is mounted!"
    # mount backup drive in rw mode
    echo "Unmounting $destpath (read-only)..."
    umount $destpath
    echo "Mounting $destpath (read-write)..."
    mount -w -U d0f558ca-571b-4db7-9cef-81bd2f4d2482 $destpath
    # determine if this is initial back / look for existing backupfolders
    for f in $destpath/backup.*; do
        [ -e $f ] && firstbackup=false || firstbackup=true
        break
    done
    # case firstbackup
    # if first time, then command is different and doesn't need hardlink option.
    # rsync wout hardlink option
    if [ $firstbackup = true ]; then
        echo "Creating new backup dir: $destpath$newfn; first iteration."
        mkdir $destpath$newfn
        rsync -aEHvq $srcpath $destpath$newfn 
    else
        # case incrementbackup
        # identify last backup folder for hardlink target
        for fn in ${destpath}backup.*; do
        #    echo $fn
            fndatestr=$(echo ${fn##${destpath}backup.})
            #  date format reference YYYY-MM-DD_HHmmss
            fndate=$(date +%s --date="${fndatestr:0:10}T${fndatestr:11:2}:${fndatestr:13:2}:${fndatestr:15:2}") 
            (( fndate > newestfndate )) && newestfndate=$fndate
        done
        lastfn=backup.$(date +%Y-%m-%d_%H%M%S --date=@$newestfndate)
        #echo $lastfn
        
        # rsync with hardlink option to last backup folder
        echo "Creating new backup dir: $destpath$newfn; incremental update.."
        mkdir $destpath$newfn
        rsync -aEHvq --delete --link-dest=$destpath$lastfn $srcpath $destpath$newfn 
        # clean up goes here, delete backups older than 'oldestkeeper'
        #  will need some sort of ifexist check first
        # need to set oldestfndate to now for oldest comparison to work below
        oldestkeepdate=$(date +%s --date="$backupage")
        echo "Looking for backups older than $(date +%Y-%m-%d_%H%M%S --date="$backupage") to delete..."
        for fn in ${destpath}backup.*; do
            fndatestr=$(echo ${fn##${destpath}backup.})
            fndate=$(date +%s --date="${fndatestr:0:10}T${fndatestr:11:2}:${fndatestr:13:2}:${fndatestr:15:2}") 
            if (( fndate < oldestkeepdate )); then
                echo "Deleting: $fn"
                rm -r $fn
            fi
        done
    fi 
    # adding code to backup timemachine files
    # only one backup iteration since timemachine has it already built in.
    #
    echo "Syncing Time Machine files..."
    rsync -aEHvq --delete /timemachine/ ${destpath}timemachinebackup/

    # remount backup drive as read-only
    umount $destpath
    mount -r -U d0f558ca-571b-4db7-9cef-81bd2f4d2482 $destpath
    echo "$destpath has been remounted as (read-only)"
else
    echo "RAID was not mounted!"
fi

