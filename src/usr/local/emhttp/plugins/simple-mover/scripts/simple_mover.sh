#!/bin/bash

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

################### general
###
simple_mover_list_path="/usr/local/emhttp/plugins/simple-mover/lists"

simple_listupdater="/usr/local/emhttp/plugins/simple-mover/scripts/simple_listupdater.sh"

mover_shares_list="$simple_mover_list_path/mover_shares_list.txt"
ls -d /boot/config/shares/* | sed 's|/boot/config/shares/||g' | sed 's|.cfg||g' > $mover_shares_list

size_list="$simple_mover_list_path/mover_size_list.txt"
size_list_sorted="$simple_mover_list_path/mover_size_list_sorted.txt"
age_list="$simple_mover_list_path/mover_age_list.txt"
age_list_sorted="$simple_mover_list_path/mover_age_list_sorted.txt"

age_size_list="$simple_mover_list_path/mover_age_size_list.txt"

touch $simple_mover_exl && chmod 777 $simple_mover_exl
touch $cache_mover_exl && chmod 777 $cache_mover_exl

rm $size_list 2> /dev/null
rm $age_list 2> /dev/null

files_kb=()
files_kb_size="0"

mover_list="$simple_mover_list_path/mover_list.txt"
no_mover_list="$simple_mover_list_path/mover_not_list.txt"
rsync_list="$simple_mover_list_path/mover_rsync_list.txt"
sum_excl_list="$simple_mover_list_path/mover_sum_excl_list.txt"

sum_excl_src="$simple_mover_exl $cache_mover_exl"

total_move_size="0"
rm $mover_list 2> /dev/null
rm $no_mover_list 2> /dev/null
rm $sum_excl_list 2> /dev/null

## build sum exclusion list
for excluded_line in $sum_excl_src
	do
	cat "$excluded_line" >> $sum_excl_list
	done

sort -u -o $sum_excl_list{,}

### rsync mover task (cache > array Shares, Media with age / size order rules)
###
### free space on disk >> percentage free on cache
for pool_disk in $pool_disks
	do
	pool_disk="${pool_disk#/}"
	pool_disk="${pool_disk%/}"
	pool_size=$(df --output=pcent /mnt/$pool_disk | tr -dc '0-9')
	## list folders for size and age in sep lists
	for pool_folder in $pool_folders
		do
		pool_folder="${pool_folder#/}"
		pool_folder="${pool_folder%/}"
		du -d 0 /mnt/$pool_disk/$pool_folder/* 2> /dev/null | awk '{for(i=1; i<=NF; ++i) printf "%s ", $i; print ""}' | sed 's/[[:blank:]]*$//' >> $size_list
		ls -ond -T 1 --time-style=+%s /mnt/$pool_disk/$pool_folder/* 2> /dev/null | awk '{for(i=5; i<=NF; ++i) printf "%s ", $i; print ""}' | sed 's/[[:blank:]]*$//' >> $age_list
		### calculate total_kb_size to free, single files in Share
		files_kb+=$(ls -la /mnt/$pool_disk/$pool_folder 2> /dev/null | grep ^- | awk '{print $5}' | awk -F '=' '$1 > 1000 {print $0}')
		if [ ! -z "$files_kb" ];then
			files_kb_size=$(dc <<< '[+]sa[z2!>az2!>b]sb'"${files_kb[*]}lbxp")
		fi
		done
		## sort folders for size and age in sep lists to showoff only
		sort -gr -o $size_list{,}
		cat $size_list | numfmt --from-unit=1024 --to=iec --format="%.0f" > $size_list_sorted
		sort -g -o $age_list{,}
		awk '{ sub(/[0-9]{10}/, strftime("%Y-%m-%d %H:%M", substr($0,0,10))) }1' $age_list > $age_list_sorted
		## build working list with age and size and sorted list
		sed -i -r 's/ +/,/' $age_list
		sed -i -r 's/ +/,/' $size_list
		join -t',' --check-order -1 2 -2 2 <(sort -t',' -k 2 $age_list) <(sort -t',' -k 2 $size_list) > $age_size_list
		if [[ $use_prio == "age" ]];then
			echo "sorting order is age, oldest 1st"
			sort -t',' -k 2 -g -o $age_size_list{,}
		elif [[ $use_prio == "size" ]];then
			echo "sorting order is size, largest 1st"
			sort -t',' -k 3 -gr -o $age_size_list{,}
		else
			echo "sorting order is none, alphabetical order by folder names"
		fi
		## calculate min_age to check when moving
		min_age_now=$(date +%s)
		min_age_duration=$(echo "$(($min_age*86400))")
		min_age_date=$(echo "$(($min_age_now-$min_age_duration))")
		### calculate total_kb_size to free, general
		total_pool_size=$(df --total /mnt/$pool_disk | tail -1 | awk {'print $2'})
		pool_to_free=$(expr $pool_size - $min_free)
		total_kb_size=$(($total_pool_size * $pool_to_free / 100))
		### calculate total_kb_size to free, cached files
        cached_kb_size="0"
        shopt -s lastpipe
		cat $sum_excl_list | while read cached_path
		do
        cached_kb=$(du -s "$cached_path" | tail -1 | cut -d "/" -f 1 || true)
        if [[ $cached_kb -gt 0 ]]; then
            cached_kb_size=$(expr $cached_kb_size + $cached_kb)
        fi
        done
        total_kb_size=$(expr $total_kb_size + $cached_kb_size)
		### calculate total_kb_size to free, cached files, single files in Share
		if [[ files_kb_size -gt "1000" ]]; then
			files_kb_size=$(($files_kb_size / 1000))
		else
			files_kb_size="0"
		fi
        total_kb_size=$(expr $total_kb_size + $files_kb_size)
		### building mover list for rsync (actually exlusion list)
		cat $age_size_list | while read move_folders
			do
			move_age=$(echo $move_folders | cut -d "," -f 2)
			move_size=$(echo $move_folders | cut -d "," -f 3)
			move_name=$(echo $move_folders | cut -d "," -f 1)
			if [[ "$move_age" -gt "$min_age_date" ]]; then
				echo "$move_name" >> $no_mover_list
			elif [[ "$total_move_size" -lt "$total_kb_size" ]] && [[ "$move_age" -lt "$min_age_date" ]]; then
				echo "$move_name" >> $mover_list
				total_move_size+=" $move_size"
				total_move_size=$(dc <<< '[+]sa[z2!>az2!>b]sb'"${total_move_size[*]}lbxp")
			else
				echo "$move_name" >> $no_mover_list
			fi
			done
		total_move_check_size=$total_move_size
		total_move_size=$(echo $total_move_size | numfmt --from-unit=1024 --to=iec --format="%.0f")
		echo "$total_move_size in queue to move when limits are reached, min $max_used% fillrate on $pool_disk"
		echo "min. $min_age days old to reach $min_free% treehold on $pool_disk"

		### merge exlusion lists for rsync, cache mover plugin, mover tuning plugin, simple mover plugin
		mover_source_files="$no_mover_list $simple_mover_exl $cache_mover_exl"
		for mover_line in $mover_source_files
			do
			cat "$mover_line" >> temp_no_mover_list
			done
		mv temp_no_mover_list $no_mover_list
		sort -u -o $no_mover_list{,}
		### build rsync compatible skip list
		cp $no_mover_list $rsync_list
		for pool_folder in $pool_folders
			do
			pool_folder="${pool_folder#/}"
			pool_folder="${pool_folder%/}"
			sed -i -e "s|/mnt/$pool_disk/$pool_folder||g" $rsync_list
			done

	done

### update mover ignore list ###
$simple_listupdater

### rsync task (cache > array Shares, Media with age / size order rules)
for pool_disk in $pool_disks
	do
	pool_disk="${pool_disk#/}"
	pool_disk="${pool_disk%/}"
	pool_size=$(df --output=pcent /mnt/$pool_disk | tr -dc '0-9')
	if [[ $pool_size -ge $max_used ]]; then
		echo "/mnt/$pool_disk currently used ($pool_size%), limit ($max_used%), processing files"
		total_target_check_size=$(df --total /mnt/$move_target | tail -1 | awk {'print $4'})
		if [[ $total_move_check_size -ge $total_target_check_size ]]; then
			echo "$move_target has not enough space, aborting here"
			exit;
		fi
		### rsync
		for pool_folder in $pool_folders
			do
			pool_folder="${pool_folder#/}"
			pool_folder="${pool_folder%/}"
			$rsync_simple --exclude-from="$rsync_list" "/mnt/$pool_disk/$pool_folder/" "/mnt/$move_target/$pool_folder/"
			find "/mnt/$pool_disk/$pool_folder/*" -type d -empty -delete  2> /dev/null
			done		
	else
		echo "/mnt/$pool_disk used ($pool_size%), min limit is ($max_used%), nothing todo"
	fi
	done

exit;
