#!/bin/bash

#purpose: this script was created to notifiy the Technology Department via ticket when the batteries have reached 20 percent or below and should be replaced in each conference room. 
#created by: Dwight Banks...
#date: March 10, 2021



#get computer serial number, will be used in jamf api call 
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
#get computer room computer is in using jamf api
room=$(curl -s -H "Authorization: Basic_Token_Goes_Here" -H "accept: application/xml" https://jss.company.com:8443/JSSResource/computers/serialnumber/$serialNumber -X GET | xmllint --xpath '/computer/location/room/text()' -)
#get building computer is in using jamf api
building=$(curl -s -H "Authorization: Basic_Token_Goes_Here " -H "accept: application/xml" https://jss.company.com:8443/JSSResource/computers/serialnumber/$serialNumber -X GET | xmllint --xpath '/computer/location/building/text()' -)
#samanage ticket description 
keymessage="REPLACE KEYBOARD BATTERIES ASAP"
mousemessage="REPLACE MOUSE BATTERIES ASAP"
#get bluetooth battery percentage for all bluetooth keyboard and mouse models
MAGKEYBOARD=$(ioreg -r -l -n AppleBluetoothHIDKeyboard | grep -E '"BatteryPercent" = |^  \|   "Product Name" = ' | awk -F " " '{print $4}')
MAGICKEYBOARD=$(ioreg -l | grep -A 10 "Magic Keyboard" | grep '"BatteryPercent" =' | sed 's/[^0-9]*//g')
MAGICKEYBOARDNUM=$(ioreg -l | grep -A 10 "Magic Keyboard with Numeric Keypad" | grep '"BatteryPercent" =' | sed 's/[^0-9]*//g')
MAGICMOUSE=$(ioreg -n BNBMouseDevice | grep -F BatteryPercent | grep -F -v { | sed 's/[^[:digit:]]//g')
MAGICMOUSEN=$(ioreg -l | grep -A 10 "Magic Mouse 2" | grep '"BatteryPercent" =' | sed 's/[^0-9]*//g')


#Samanage Function
createTicket (){
	curl -H "X-Samanage-Authorization: Bearer_Token_Goes_Here"  -H 'Accept: application/xml' -H 'Content-Type:text/xml' -X POST https://api.samanage.com/incidents.xml -d "<incident><name>$1 - $2</name><priority>High</priority><requester><email>enter_your_email_here</email></requester><description>$3</description></incident>"
}

if [[ "$MAGICKEYBOARD" -lt 21 && "$MAGICKEYBOARD" != "" ]] || [[ "$MAGKEYBOARD" -lt 21 && "$MAGKEYBOARD" != "" ]] || [[ "$MAGICKEYBOARDNUM" -lt 21 && "$MAGICKEYBOARDNUM" != ""  ]];
	
then
	#samange api call to create incident
	createTicket "$building" "$room" "$keymessage"
	
elif [[ "$MAGICMOUSE" -lt 21  && "$MAGICMOUSE" != "" ]] || [[ "$MAGICMOUSEN" -lt 21 && "$MAGICMOUSEN" != "" ]]; 

then
	#samange api call to create incident
	createTicket "$building" "$room" "$mousemessage"
else 
	exit 0 
fi 
exit 0