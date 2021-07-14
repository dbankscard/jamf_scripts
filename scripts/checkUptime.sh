#!/bin/zsh

# Name: checkUpTime.sh
# Date: September 15,2017 
# Modified by: Dwight Banks
# Purpose:  look for machines that have not been restarted in X number of days.
# Requirements:  cocoaDialog has to be installed on the local machine or you can modify the script to use jamfHelper to display the message. 
# How To Use:  create a policy in  JSS with this script set to run once every day.
# Version:1.0.0

## Global Variables and Stuff
CD="/usr/local/cocoa-dialog/cocoaDialog.app/Contents/MacOS/cocoaDialog" ### <--- path to where you store cocoDialog on local machine
cdIcon="/usr/local/GHC/GHCicon.png"
cdTitle="Your Mac Needs A Restart"
username="$(stat -f%Su /dev/console)"
realname="$(dscl . -read /Users/$username RealName | cut -d: -f2 | sed -e 's/^[ \t]*//' | grep -v "^$")"
#if [[ -z $userRealName ]]; then
#	userRealName=`dscl . -read /Users/$loggedInUser | awk '/^RealName:/,/^RecordName:/' | sed -n 2p | cut -c 2-`
#fi


#hardcoded threshold of uptime limit 
dayLimit='1'

boottime=$(sysctl kern.boottime | awk '{print $5}' | tr -d ,)
boottimeFormatted=$(date -jf %s $boottime +%F\ %T)
currentday=`date +"%Y-%m-%d"`
#### MAIN CODE ####
days=`uptime | awk '{ print $3}' | sed 's/,//g'`  # grabs the number of uptime in days

if [ $username = "root" ]; then
	echo "logged in user is root, exiting.."
	exit 1 
elif [[ "$days" -gt "$dayLimit" ]]; then
	cdText="$realname your computer has not been restarted in more than $days days.  Please restart ASAP.  Thank you."
	msgbox=`$CD ok-msgbox --title "$cdTitle" --no-cancel --informative-text "$cdText" --icon-file $cdIcon`
fi

exit 0