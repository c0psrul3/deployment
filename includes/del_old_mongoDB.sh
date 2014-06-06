#!/usr/bin/env bash

ago=${1:-"-1 day"}
varDate=$(date -d"${ago}" +%m%d%Y)

mongodbUsage="df -H /var/lib/mongodb | grep -vE '^Filesystem' | awk '{ print $5 }'"

if [ $# -lt 1 ] ; then
	echo "No arguments given, removing all dbs older than 18 Hours"
fi

mdbname=${2:-"test_db"}
mdbhost=${3:-"mongo.example.com"}

ssh -l admin ${mdbhost} "sudo ls -1 /var/lib/mongodb/${mdbname}-bak-${varDate}*"
ssh -l admin ${mdbhost} "sudo rm -rf /var/lib/mongodb/${mdbname}-bak-${varDate}*"
#ssh ${mdbhost} "sudo ls -1 /var/lib/mongodb/${mdbname}-bak-${varDate}*"

#mongodbUsage=$(ssh admin@mongo.example.com "df -H /var/lib/mongodb | grep -vE '^Filesystem'")

#connect to mongo db and copy db.
#mongo $mdbhostDest --eval "print(db.copyDatabase(\"${mdbname}\",\"${mdbname}-bak-${NOW}\",\"${mdbhostOrigin}\"))"

