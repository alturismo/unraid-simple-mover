#!/bin/bash

################################

simple_mover_list_path="/usr/local/emhttp/plugins/simple-mover/lists"

################################
simple_mover_log="$simple_mover_list_path/simple_mover_log.txt"
simple_mover_I_log="$simple_mover_list_path/simple_mover_I_log.txt"

##########################
cat /var/log/syslog | grep -i "simple-mover:" > $simple_mover_log
tail -n 999 $simple_mover_log > myfile.tmp
cat myfile.tmp > $simple_mover_log
rm myfile.tmp
cat /var/log/syslog | grep -i "simple-mover-basic:" > $simple_mover_I_log
tail -n 999 $simple_mover_I_log > myfile.tmp
cat myfile.tmp > $simple_mover_I_log
rm myfile.tmp

mover_shares_list="$simple_mover_list_path/mover_shares_list.txt"
ls -d /boot/config/shares/* | sed 's|/boot/config/shares/||g' | sed 's|.cfg||g' > $mover_shares_list

exit;