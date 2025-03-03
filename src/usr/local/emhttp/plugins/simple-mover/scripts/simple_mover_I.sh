#!/bin/bash

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

################### general
###
simple_mover_list_path="/usr/local/emhttp/plugins/simple-mover/lists"

simple_listupdater="/usr/local/emhttp/plugins/simple-mover/scripts/simple_listupdater.sh"

mover_shares_list="$simple_mover_list_path/mover_shares_list.txt"
ls -d /boot/config/shares/* | sed 's|/boot/config/shares/||g' | sed 's|.cfg||g' > $mover_shares_list

size_list_I="$simple_mover_list_path/mover_size_list_i.txt"
age_list_I="$simple_mover_list_path/mover_age_list_I.txt"
age_size_list_I="$simple_mover_list_path/mover_age_size_list_I.txt"

touch $simple_mover_exl_I && chmod 777 $simple_mover_exl_I
touch $cache_mover_exl && chmod 777 $cache_mover_exl

rm $size_list_I 2> /dev/null
rm $age_list_I 2> /dev/null

files_kb=()
files_kb_size="0"

mover_list_I="$simple_mover_list_path/mover_list_I.txt"
no_mover_list_I="$simple_mover_list_path/mover_not_list_I.txt"
rsync_list_I="$simple_mover_list_path/mover_rsync_list_I.txt"
sum_excl_src="$simple_mover_exl_I $cache_mover_exl"
sum_excl_list="$simple_mover_list_path/mover_sum_excl_list.txt"

rm $mover_list_I 2> /dev/null
rm $no_mover_list_I 2> /dev/null
rm $sum_excl_list 2> /dev/null

touch $no_mover_list_I

## build sum exclusion list
for excluded_line in $sum_excl_src
	do
	cat "$excluded_line" >> $sum_excl_list
	done

sort -u -o $sum_excl_list{,}

### update mover ignore list ###
$simple_listupdater

### rsync_I run pre script (cache only Shares, backup to disk or remote)
if [ ! -z "$pre_simple_I" ]; then
	bash "$pre_simple_I"
fi

### rsync_I mover task (cache > array Shares, only simple min age rule, no size rules, no ordering)
###
### rsync_I task (cache > array Shares, only simple min age rule, no size rules, no ordering)
for pool_disk in $pool_disks_I
	do
	pool_disk="${pool_disk#/}"
	pool_disk="${pool_disk%/}"
	for pool_folder in $pool_folders_I
		do
		pool_folder="${pool_folder#/}"
		pool_folder="${pool_folder%/}"
		## build working list with age and size
		du -d 0 /mnt/$pool_disk/$pool_folder/* 2> /dev/null | awk '{for(i=1; i<=NF; ++i) printf "%s ", $i; print ""}' | sed -r 's/ +/,/' | sed 's/[[:blank:]]*$//' >> $size_list_I
		ls -ond -T 1 --time-style=+%s /mnt/$pool_disk/$pool_folder/* 2> /dev/null | awk '{for(i=5; i<=NF; ++i) printf "%s ", $i; print ""}' | sed -r 's/ +/,/' | sed 's/[[:blank:]]*$//' >> $age_list_I
		sed -i -r 's/\\//g' $age_list_I
		sed -i -r 's/\\//g' $size_list_I
		sed -i -r 's:/*$::' $age_list_I
		sed -i -r 's:/*$::' $size_list_I
		join -t',' --check-order -1 2 -2 2 <(sort -t',' -k 2 $age_list_I) <(sort -t',' -k 2 $size_list_I) > $age_size_list_I
		## calculate min_age to check when moving
		min_age_now=$(date +%s)
		min_age_duration=$(echo "$(($min_age_I*86400))")
		min_age_date=$(echo "$(($min_age_now-$min_age_duration))")
		### building mover list for rsync (actually exlusion list)
		total_move_size="0"
		shopt -s lastpipe
		cat $age_size_list_I | while read move_folders
			do
			move_age=$(echo $move_folders | cut -d "," -f 2)
			move_size=$(echo $move_folders | cut -d "," -f 3)
			move_name=$(echo $move_folders | cut -d "," -f 1)
			if [[ "$move_age" -gt "$min_age_date" ]]; then
				echo "$move_name" >> $no_mover_list_I
			elif [[ "$move_age" -lt "$min_age_date" ]]; then
				echo "$move_name" >> $mover_list_I
				total_move_size=$((total_move_size+$move_size))  
			else
				echo "$move_name" >> $no_mover_list_I
			fi
			done
		total_move_check_size=$total_move_size
		total_move_size=$(echo $total_move_size | numfmt --from-unit=1024 --to=iec --format="%.0f")
		echo "$total_move_size open to move when timer is reached $min_age_I days old"
		### merge exlusion lists for rsync, simple mover plugin
		mover_source_files_I="$no_mover_list_I $simple_mover_exl_I"
		for mover_line in $mover_source_files_I
			do
			cat "$mover_line" >> temp_no_mover_list_I
			done
		mv temp_no_mover_list_I $no_mover_list_I
		sort -u -o $no_mover_list_I{,}
		### build rsync compatible skip list
		cp $no_mover_list_I $rsync_list_I
		sed -i -e "s|/mnt/$pool_disk/$pool_folder||g" $rsync_list_I
		### check free on target
		total_target_check_size=$(df --total /mnt/$move_target_I | tail -1 | awk {'print $4'})
		if [[ $total_move_check_size -ge $total_target_check_size ]]; then
			echo "$move_target_I has not enough space, aborting here"
			exit;
		fi
		### rsync
		if [[ $total_move_check_size == "0"  ]]; then
			echo "nothing to move, done here"
		else
			$rsync_simple_I --exclude-from="$rsync_list_I" "/mnt/$pool_disk/$pool_folder/" "/mnt/$move_target_I/$pool_folder/"
			find /mnt/$pool_disk/$pool_folder/* -type d -empty -delete  2> /dev/null
		fi

		done
	done

### rsync_II run post script (cache only Shares, backup to disk or remote)
if [ ! -z "$post_simple_I" ]; then
	bash "$post_simple_I"
fi