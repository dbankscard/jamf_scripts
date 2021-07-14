#!/bin/bash
#purpose: the following script was created to return your Jamf Pro health status
#Created by Dwight Banks




userInput=$(osascript << EOF
set theResponse to display dialog "Enter your Jamf Pro Instance URL?" default answer "jss.mycompany.com" with icon note buttons {"Cancel", "Continue"} default button "Continue" 
EOF
)


jamfProURL=$( echo $userInput | awk -F ":" '{print $3}' )
#get healthcheck of jss instance and store in variable
jamfPro=$(curl -s "https://$jamfProURL:8443/healthCheck.html")

if [ "$jamfPro" == '[]' ];then
	echo "The Jamf Pro web app is running without error."
elif
	[ "$jamfPro" == '[{"healthCode":1,"httpCode":503,"description":"DBConnectionError"}]' ];then
		echo "An error occurred while testing the database connection."
	elif
		[ "$jamfPro" == '[{"healthCode":2,"httpCode"200:,"description":"SetupAssistant"}]' ];then
			echo "The Jamf Pro Setup Assistant was detected."
		elif
			[ "$jamfPro" == '[{"healthCode":3,"httpCode":503,"description":"DBConnectionConfigError"}]' ];then
				echo "A configuration error occurred while attempting to connect to the database."
			elif
				[ "$jamfPro" == '[{"healthCode":4,"httpCode":503,"description":"Initializing"}]' ];then
					echo "The Jamf Pro web app is initializing."
				elif
					[ "$jamfPro" == '[{"healthCode":5,"httpCode":503,"description":"ChildNodeStartUpError"}]' ];then
						echo "An instance of the Jamf Pro web app in a clustered environment failed to start."
					elif
						[ "$jamfPro" == '[{"healthCode":6,"httpCode":503,"description":"InitializationError"}]' ];then
							echo "A fatal error occurred and prevented the Jamf Pro web app from starting."
						fi
exit 0
