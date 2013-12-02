#!/bin/bash

echo $0 Started

ROOT=""
ROOT="/home/dobek/code/prv/continuous-backup"
# set -x

ETC="${ROOT}/etc/continuous-backup"
source ${ETC}/continuous-backup.cfg
source ${ETC}/server


log_header() {
	echo --------------------------------------------------------------------------- #>> $LOG
	echo TIMESTAMP: $1
	echo === sync-list: $DIR_LIST ===
	cat $DIR_LIST
	echo
	echo === ignore-list: $IGNORE ===
	cat $IGNORE
	echo
	echo --------------------------------------------------------------------------- #>> $LOG
}

log() {
	echo MAIN [`date`] $* | tee -a $LOG_LOG
}

debug() {
	log DEBUG: $*
}

mkdir -p ${LOG_DIR}
if [ ! -f ${LOG_STARTED} ]; then
	echo "none" > ${LOG_STARTED}
fi
if [ ! -f ${LOG_COMPLETED} ]; then
	echo "none" > ${LOG_COMPLETED}
fi
if [ ! -f ${LOG_UPLOADED} ]; then
	echo "201301010000" > ${LOG_UPLOADED}
fi

while true ; do

	debug 2
	COMPLETED=`cat $LOG_COMPLETED`
	STARTED=`cat $LOG_STARTED`
	UPLOADED=`cat $LOG_UPLOADED`

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
		# if [ `cat /sys/class/net/eth0/operstate` = "up" ] ; then
			log Syncing /etc
			COMMAND="rsync -arzvt  \
				/etc   \
				--exclude-from=$IGNORE   \
				--bwlimit=${BWLIMIT} \
				--delete-delay \
				--password-file=${PASSWORD} \
				/  \
				rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
			log EXECUTE: $COMMAND
			$COMMAND >> $LOG_LOG 2>&1


			log Syncing files updated after ${UPLOADED}
			debug 5.1
			touch -t ${UPLOADED} ${TIMEFROM}
			find `cat $DIR_LIST` -newer ${TIMEFROM} -mount > $HOTLIST
			debug 5.2
			LAST_RSYNC=`date +"%Y%m%d-%H%M%S"`
			COMMAND="rsync -azvt  \
				--files-from=$HOTLIST   \
				--exclude-from=$IGNORE   \
				--bwlimit=${BWLIMIT} \
				--password-file=${PASSWORD} \
				/  \
				rsync://${RSYNC_SERVER}/BackInTime/$STARTED/"
			debug 5.3
			log EXECUTE: $COMMAND
			$COMMAND >> $LOG_LOG 2>&1 \
			&& break

		# fi
		log FAILED - will try in ${RETRY_SLEEP}
		sleep ${RETRY_SLEEP}
		debug 6
	done

	log "SYNC FINISHED"
	rsync -avzt --password-file ${PASSWORD} $LOG_LOG rsync://${RSYNC_SERVER}/BackInTime/$STARTED/
	echo $STARTED > $LOG_COMPLETED
	echo ${LAST_RSYNC} > $LOG_UPLOADED
	log DONE
	sleep ${DONE_SLEEP}
	debug 8

done

