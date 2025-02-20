################################
source /boot/config/plugins/simple-mover/simplemoversettings

### Check if another instance of this Program is running
pidof -o %PPID -x $0 >/dev/null && echo "ERROR: Program $0 already running" && exit 1

################################
if [ "$unraid_syslog" == "yes" ]; then

log_message() {
  while IFS= read -r line; do
    logger "simple-mover: ${line}"
  done
}
exec > >(log_message) 2>&1

fi

################################
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

### check if mover tuning list update is wanted

if [ -z $mover_tuning_excl ]; then
	echo "update mover tuning exclusions are not configured, !!! BEWARE !!! Standard mover will run its own procedure !!!"
	echo "recommended to use mover tuning and configure path to mover tuning exclusion list !!!"
	echo "simple mover will then update the list for mover tuning to exclude simple mover folders"
	exit;
fi

### update mover tuning ignore list ###
for pool_disk in $pool_disks
	do
	pool_disk="${pool_disk#/}"
	pool_disk="${pool_disk%/}"
	for pool_folder in $pool_folders
		do
		pool_folder="${pool_folder#/}"
		pool_folder="${pool_folder%/}"
		echo "/mnt/$pool_disk/$pool_folder" >> $mover_tuning_excl
		done
	done

################################
if [ "$unraid_syslog" == "yes" ]; then

log_message() {
  while IFS= read -r line; do
    logger "simple-mover-basic: ${line}"
  done
}
exec > >(log_message) 2>&1

fi

### update mover tuning ignore list ###
for pool_disk in $pool_disks_I
	do
	pool_disk="${pool_disk#/}"
	pool_disk="${pool_disk%/}"
	for pool_folder in $pool_folders_I
		do
		pool_folder="${pool_folder#/}"
		pool_folder="${pool_folder%/}"
		echo "/mnt/$pool_disk/$pool_folder" >> $mover_tuning_excl
		done
	done

### update mover tuning ignore list, sort and remove dublette ###
sort -u -o $mover_tuning_excl{,}

exit;