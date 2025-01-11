#!/bin/bash

################################
source /boot/config/plugins/simple-mover/simplemoversettings

################################
configfile="/boot/config/plugins/simple-mover/simplemoversettings"

################################
if [ ! -z "$simple_cron_time" ]; then
( crontab -l | grep -v -F "Simple_Mover " ; echo "# Cron Job for Simple_Mover plugin" ) | crontab -
( crontab -l | grep -v -F "simple_mover.sh" ; echo "$simple_cron_time /usr/local/emhttp/plugins/simple-mover/scripts/simple_mover.sh" ) | crontab -
sed -i 's/^simple_cron_state=.*/simple_cron_state="started"/' $configfile
else
crontab -l | grep -v "Simple_Mover "  | crontab -
crontab -l | grep -v "simple_mover.sh"  | crontab -
sed -i 's/^simple_cron_state=.*/simple_cron_state="stopped"/' $configfile
fi

exit;