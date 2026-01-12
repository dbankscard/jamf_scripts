#!/bin/bash
#purpose: this script was created to remove users vpn configuration profiles from the Jamf Pro server after the company has begun the offboarding process.
#Each vpn config profile name follows this syntax - "VPN - Firstname Lastname". This can placed in Self Service scoped ONLY to the IT department to use.  

#jamf pro url 
jamfProURL="https://jss.companyname.com/JSSResource"

 #jamf credentials encoded using base64
jamfcreds=$(echo "username:password" | base64 )

#get username
username=$(osascript -e 'tell application "System Events" to text returned of (display dialog "Enter user first and last name." default answer "John Smith" buttons {"Cancel", "OK"} default button 2 with icon {"/path/to/file.png"} with title "Removing User VPN Configuration Profiles"  )' )

#check status of osascript, if user clicked cancel exit script.. 
if [ "$?" != "0" ] ; then
	echo "User aborted. Exiting..."
	exit 1
fi
#check if username matches the Firstname Lastname syntax"
until [[ "$username" =~ ^[A-Z][a-z]+[[:space:]]+[A-Z][a-z]+$ ]]; do
	username=$(osascript -e 'tell application "System Events" to text returned of (display dialog "You did not enter the first and last name. Enter user first and last name." default answer "John Smith" buttons {"Cancel", "OK"} default button 2 with icon {"/path/to/file.png"})' )
	#check status of osascript, if user clicked cancel exit script..
	if [ "$?" != "0" ] ; then
		echo "User aborted. Exiting..."
		exit 1
	fi

done

#get config profile id
configID=$(curl -s -H 'Authorization: Basic '$jamfcreds'' -X GET "$jamfProURL/osxconfigurationprofiles" -H "accept: application/xml" | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}')

#get config profile name
for id in $configID
do
	config_name=$(curl -s -H 'Authorization: Basic '$jamfcreds'' -X GET "$jamfProURL/osxconfigurationprofiles/id/$id" -H "accept: application/xml" | xmllint --xpath '/os_x_configuration_profile/general/name/text()' - )
	
	#remove config profile from Jamf Pro server.. 
	if [[ $config_name = "VPN - $username" ]]; then 
		echo "Removing $config_name"
		curl -s -H 'Authorization: Basic '$jamfcreds'' "$jamfProURL/osxconfigurationprofiles/id/$id" -X DELETE
	fi
done





