#!/bin/bash

################################
source /boot/config/plugins/simple-mover/simplemoversettings

### Check if another instance of this Program is running
pidof -o %PPID -x $0 >/dev/null && echo "ERROR: Program $0 already running" && exit 1

################################
if [ "$unraid_syslog" == "yes" ]; then

log_message() {
  while IFS= read -r line; do
    logger "simple-mover-basic: ${line}"
  done
}
exec > >(log_message) 2>&1

fi

################################
configfile="/boot/config/plugins/simple-mover/simplemoversettings"

mover_dis_entry="exit;  ### stopper here from simple_mover"
mover_file="/usr/local/sbin/mover"

################################
if [ ! -z "$unraid_mover" ]; then
	if [ "$unraid_mover" == "disable" ]; then
		sed -i "2i $mover_dis_entry" $mover_file
		echo "standard mover is disabled now"
	fi
else
	if [ ! "$unraid_mover" == "disable" ]; then
		sed -i "/$mover_dis_entry/d" $mover_file
		echo "standard mover is enabled"
	fi
fi

exit;

##	sed -i "2i exit;  ### stopper here from simple_mover" /usr/local/sbin/mover
##	sed -i "/simple_mover/d" /usr/local/sbin/mover