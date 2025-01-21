#!/bin/bash

################################
source /boot/config/plugins/simple-mover/simplemoversettings

################################
configfile="/boot/config/plugins/simple-mover/simplemoversettings"

################################
if [ ! -z "$simple_I_cron_time" ]; then
( crontab -l | grep -v -F "Simple_Basic_Mover " ; echo "# Cron Job for Simple_Basic_Mover plugin" ) | crontab -
( crontab -l | grep -v -F "simple_mover_I.sh" ; echo "$simple_I_cron_time /usr/local/emhttp/plugins/simple-mover/scripts/simple_mover_I.sh >/dev/null 2>&1" ) | crontab -
sed -i 's/^simple_I_cron_state=.*/simple_I_cron_state="started"/' $configfile
else
crontab -l | grep -v "Simple_Basic_Mover "  | crontab -
crontab -l | grep -v "simple_mover_I.sh"  | crontab -
sed -i 's/^simple_I_cron_state=.*/simple_I_cron_state="stopped"/' $configfile
fi

exit;