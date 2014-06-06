#!/usr/bin/env bash

###############
# get free space of a server

# the HOST we are getting free space from
HOST="example-host.com"
: ${HOST:=$1}

ssh $HOST "df -H" | grep -vE '^Filesystem|tmpfs|cdrom|rootfs|udev|/dev/xvda1' | awk '{print $5 " " $1}' | while read line ; do
  usep=$(echo $line | awk '{ print $1 }' | cut -d'%' -f1 )
  partition=$(echo $line | awk '{ print $2 }' )
  if [[ $usep -ge 85 ]]; then
    echo "Server $HOST might run out of disk space soon! It's at ($usep%) as of $(date).\n Because of this, automated backups may be halted." | mail -s "[${HOST}] Running out of space!!1 \"$partition ($usep%)\"" root
    exit 1
  fi
  exit 0
done
