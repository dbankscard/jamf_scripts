#!/bin/bash
#purpose: this script was created to add the VPN menu item to the toolbar.. 


# Identify the username of the logged-in user
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Identify the UID of the logged-in user
user_uid=$(id -u "$loggedInUser")

#add VPN menu item to toolbar
/bin/launchctl asuser "$user_uid" /usr/bin/open "/System/Library/CoreServices/Menu Extras/VPN.menu"


exit 0
