#!/bin/bash
#Purpose:This script was created to change the audio input/output source depending on which SSID they are connected to. If neither of the audio devices are available the audio source will default to the built-in option. The script uses the switchAudioSource binary from https://github.com/deweller/switchaudio-osx/. The binary can be installed using your MDM before using this script in a policy. 
#Created by: Dwight Banks
#Date: 12.13.2018

#get current SSID name
CURRENTWIFI=` /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print substr($0, index($0, $2))}'`

#get connected audio devices  
Corsair=`/usr/local/bin/SwitchAudioSource -a -t input | grep -e "Corsair VOID Wireless Gaming Dongle"`
Jabra=`/usr/local/bin/SwitchAudioSource -a -t input | grep -e "Jabra Link 370"`


			if [ "$CURRENTWIFI" == "SSID_Name" -a  "$Corsair" == "Corsair VOID Wireless Gaming Dongle (input)" ] ;then
				
				/usr/local/bin/switchAudioSource -t input -s "Corsair VOID Wireless Gaming Dongle"
				/usr/local/bin/switchAudioSource -s "Corsair VOID Wireless Gaming Dongle"
				
			elif [ "$CURRENTWIFI" == "SSID_Name" -a "$Jabra" == "Jabra Link 370 (input)" ] ;then
			
				/usr/local/bin/switchAudioSource -t input -s "Jabra Link 370"
				/usr/local/bin/switchAudioSource -s "Jabra Link 370"
			
			else
	
				/usr/local/bin/SwitchAudioSource -t input -s "Built-in Microphone"
				/usr/local/bin/switchAudioSource -s "Built-in Output"
				
			exit 0
		
fi
