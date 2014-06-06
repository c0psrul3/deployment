#!/usr/bin/env bash

NOW=$(date +%m%d%Y%H%M)

mdbname=${1:-"test_db"}
mdbhostDest=${2:-"mongo.example.com"}
mdbhostOrigin=${3:-$mdbhostDest}

[ $# -lt 1 ] && \
	echo "No arguments given, copying \"${mdbname}\" to staging server"

#connect to mongo db and copy db.
mongo $mdbhostDest --eval "print(db.copyDatabase(\"${mdbname}\",\"${mdbname}-bak-${NOW}\",\"${mdbhostOrigin}\"))"

exit 0
