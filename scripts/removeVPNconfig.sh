#!/bin/bash
#purpose: this script is to be used when an employee separates from the company. this is the first iteration of this script which will remove vpn config profiles from the jamf pro instance by using the employee first and last name. 

##API Call Info
jamfProURL="https://jss.companyname.com/JSSResource"
#get separated username
username=$(osascript -e 'tell application "System Events" to text returned of (display dialog "Enter user first and last name." default answer "John Smith" buttons {"Cancel", "OK"} default button 2 with icon {"/usr/local/GHC/GHCicon.png"} with title "Removing User VPN Configuration Profiles"  )' )

# Check status of osascript, if user canceld exit script
if [ "$?" != "0" ] ; then
	echo "User aborted. Exiting..."
	exit 1
fi

until [[ "$username" =~ ^[A-Z][a-z]+[[:space:]]+[A-Z][a-z]+$ ]]; do
	username=$(osascript -e 'tell application "System Events" to text returned of (display dialog "You did not enter the first and last name. Enter user first and last name." default answer "John Smith" buttons {"Cancel", "OK"} default button 2 with icon {"/usr/local/GHC/GHCicon.png"})' )
	# Check status of osascript, if user canceld exit script
	if [ "$?" != "0" ] ; then
		echo "User aborted. Exiting..."
		exit 1
	fi

done

#get config profile id
configID=$(curl -s -H '' -X GET "$jamfProURL/osxconfigurationprofiles" -H "accept: application/xml" | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}')

#get config profile name
for id in $configID
do
	config_name=$(curl -s -H '' -X GET "$jamfProURL/osxconfigurationprofiles/id/$id" -H "accept: application/xml" | xmllint --xpath '/os_x_configuration_profile/general/name/text()' - )
	
	#remove config profile 
	if [[ $config_name = "VPNAZN - $username" ]]; then 
		echo "Removing $config_name"
		curl -s -H '' "$jamfProURL/osxconfigurationprofiles/id/$id" -X DELETE
	elif [[ $config_name = "VPNFUL- $username" ]]; then 
			echo "Removing $config_name"
			curl -s -H '' "$jamfProURL/osxconfigurationprofiles/id/$id" -X DELETE
		elif [[ $config_name = "VPNHQ - $username" ]]; then 
			echo "Removing $config_name"
			curl -s -H '' "$jamfProURL/osxconfigurationprofiles/id/$id" -X DELETE
	fi
done





