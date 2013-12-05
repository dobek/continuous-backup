#!/bin/bash

echo Installing Continuous-Backup ...

DIR=`dirname $0`

cp -fv usr/sbin/continuous-backup-demon.sh /usr/sbin/continuous-backup-demon.sh
RES=$?
if [ "$RES" != "0" ]; then
	echo Must be root to install Continuous-Backup
	exit $RES
fi
chmod 755 /usr/sbin/continuous-backup-demon.sh

if [ ! -e /etc/conf.d/continuous-backup ]; then
	mkdir -p /etc/conf.d/
	cp -v etc/conf.d/continuous-backup /etc/conf.d/continuous-backup
fi

if [ ! -e /etc/continuous-backup ]; then
	mkdir -p /etc/continuous-backup
	cp -v etc/continuous-backup/continuous-backup.cfg /etc/continuous-backup/continuous-backup.cfg
fi


cp -fv etc/init.d/continuous-backup /etc/init.d/continuous-backup
chmod 755 /etc/init.d/continuous-backup

echo
echo Find more information in README.md
echo
