#!/bin/bash

echo $0 Started

local RSYNC_SERVER=xxxxx.com
local RSYNC_PASSWORD=xxxxxx


LOG_DIR=/var/log/dobek-backup
LOG_COMPLETED=$LOG_DIR/completed.log
LOG_STARTED=$LOG_DIR/started.log
LOG_LOG=/dev/null

DIR="$(dirname $(readlink -f $0))"
DIR_LIST=$DIR/dirlist.txt
IGNORE=$DIR/ignore.txt
HOTLIST=/tmp/dobek-backup-just-modified.tmp

log_header() {
	echo --------------------------------------------------------------------------- #>> $LOG
	echo TIMESTAMP: $1
	echo === sync-list: $DIR_LIST ===
	cat $DIR_LIST
	echo === ignore-list: $IGNORE ===
	cat $IGNORE
	echo --------------------------------------------------------------------------- #>> $LOG
}

log() {
	echo MAIN [`date`] $* | tee -a $LOG_LOG
}

debug() {
	log DEBUG: $*
}


while true ; do

	debug 2
	COMPLETED=`cat $LOG_COMPLETED`
	STARTED=`cat $LOG_STARTED`

	if [ "$COMPLETED" = "$STARTED" ]; then
		STARTED=`date +"%Y%m%d-%H%M%S"`
		LOG_LOG=${LOG_DIR}/${STARTED}.log
		log Starting a new sync ${STARTED}
		echo $STARTED > $LOG_STARTED
	else
		LOG_LOG=${LOG_DIR}/${STARTED}.log
		log Continue the previous synch ${STARTED}
	fi

	log_header $STARTED | tee -a $LOG_LOG

	while true ; do
		debug 4
		if [ `cat /sys/class/net/eth0/operstate` = "up" ] ; then
			log Syncing files updated in the last 5 days
			debug 5.1
			find `cat $DIR_LIST` -mtime -5 > $HOTLIST
			debug 5.2
			COMMAND="rsync -azvt  \
				--files-from=$HOTLIST   \
				--exclude-from=$IGNORE   \
				--bwlimit=200 \
				/  \
				rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
			debug 5.3
			log EXECUTE: $COMMAND
			$COMMAND >> $LOG_LOG 2>&1

			if [ $? -eq 0 ]; then

				log Syncing files older then 5 days
				COMMAND="rsync -arzvt  \
					--files-from=$DIR_LIST   \
					--exclude-from=$IGNORE   \
					--bwlimit=100 \
					--delete-delay \
					/  \
					rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
				log EXECUTE: $COMMAND
				$COMMAND >> $LOG_LOG 2>&1 \
				&& break

				log Syncing /etc
				COMMAND="rsync -arzvt  \
					/etc   \
					--exclude-from=$IGNORE   \
					--bwlimit=100 \
					--delete-delay \
					/  \
					rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
				log EXECUTE: $COMMAND
				$COMMAND >> $LOG_LOG 2>&1

				log Syncing $LOG_DIR
				COMMAND="rsync -arzvt  \
					$LOG_DIR   \
					--exclude-from=$IGNORE   \
					--bwlimit=100 \
					--delete-delay \
					/  \
					rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
				log EXECUTE: $COMMAND
				$COMMAND >> $LOG_LOG 2>&1

			fi
		fi
		log FAILED - will try in 1h
		sleep 1h
		debug 6
	done

	log "SYNC FINISHED"
	rsync -avz $LOG_LOG rsync://${RSYNC_SERVER}/BackInTime/$STARTED/
	echo $STARTED > $LOG_COMPLETED
	log DONE
	sleep 24h
	debug 8

done

