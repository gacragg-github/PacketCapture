#!/bin/bash +x
#
#Configure adapters for monitor mode
#
#Prototype:		$./wifisetup.sh [-i phyX] [-c 'channel string'] [-f 'freq string']
#
#Arguments:		-i phyX,  phy to convert
#				-c 'channel string', '11 HT20', '36 80MHz'
#				-f 'freq string', '6935 160 6985'
#				-r Set channel/freq only
#
#Result:		1. Set reg domain - using custom GC (set to legally required value)
#				2. Rename adapter to wlanX, where X is from phyX
#				3. Disable NetworkManager control
#				4. Do a network scan to update reg domain
#				5. Set to monitor mode	
#				6. Configure to some channel string
#
#				Ver		Date		Notes
#Version:		0		10/2022		Orig
#
#	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.




#Defaults
regdomain="KR"
chndefault="6 HT20"
freqdefault="6935 160 6985"
setchnonly=0
resetusb=0

#Help
usage () {
	echo "Configure adapters for monitor mode"
	echo "Usage: $0 [-i phyX] [-c 'channel string'] [-f 'freq string']"
	echo "Options: (all optional)"
	echo -e "  -h                   help"
	echo -e "  -i phyX              phy to convert   Default: all"
	echo -e "  -c 'channel string'  Channel config   Default: '${chndefault}' (priority)"
	echo -e "  -f 'freq string'     Freq config      Default: '${freqdefault}'"
	echo -e "  -r                   Only set channel/freq"
	echo -e "  -y                   Reset ykush USB"
	echo -e	"  -d                   debug"
}


#Check for elevated privileges
if [[ $(id -u) -ne 0 ]]
then 
	echo "Please run with elevated privileges"
	usage
	exit 1
fi


########################################################################
#Option handling

while getopts "h?vi:c:f:ryd" opt; do
  case "$opt" in
    h|\?)
      usage
      exit 0
      ;;
    v)  verbose=1
      ;;
    i)  phyoption=$OPTARG
      ;;
    c)  chnoption=$OPTARG
      ;;
	f)  freqoption=$OPTARG
      ;;
    r)  setchnonly=1
      ;;
    y)	resetusb=1
      ;;  
    d)	set -x
      ;;  
  esac
done

#Manage settings
allphys=0
if [ -z "$phyoption" ]	#check is empty
then
	allphys=1
else
	allphys=0
fi

setchannel=0
if [ -z "$chnoption" ]	#check is empty
then
	chntoset=${chndefault}
else
	chntoset=${chnoption}
	setchannel=1
fi

setfreq=0
if [ -z "${freqoption}" ]	#check is empty
then
	freqtoset=${freqdefault}
else
	freqtoset=${freqoption}
	setfreq=1
fi

if [ "${setchannel}" == 1 ]
then
	setfreq=0
elif [ "${setchannel}" == 0 ] && [ "${setfreq}" == 0 ]
then	
	setchannel=1
fi

#Option check
echo "Check options"
[[ ! -z "${phyoption}" ]] && echo "  Phy set: ${phyoption}" || echo "  Phy: All"
[[ ! -z "${chnoption}" ]] && echo "  Chn set: ${chnoption}" || echo "  Chn default: ${chndefault}"
[[ ! -z "${freqoption}" ]] && echo "  Freq set: ${freqoption}" || echo "  Freq default: ${freqdefault}"
[[ ! -z "${setchnonly}" ]] && echo "  Set chn only: ${setchnonly}" || echo "  Set chn only: OFF"
echo "  setchannel: ${setchannel} to ${chntoset}"
echo "  setfreq: ${setfreq} to ${freqtoset}"
echo "  resetusb: ${resetusb}"

#Check for executables we need
#iw #ip #ethtool #nmcli #interfaces.sh
#ykushcmd		https://www.yepkit.com/learn/setup-guide-ykush-windows
executables=()
executables+=(iw)
executables+=(ip)
executables+=(ethtool)
executables+=(nmcli)
executables+=(interfaces.sh)
if [ "${resetusb}" == 1 ]
then
	executables+=(ykushcmd)
fi

for exe in ${executables[@]}
do
	if ! hash ${exe} 2>/dev/null
	then
		echo "Executable ${exe} could not be found.  Aborting."
		usage
		exit 3
	else
		echo "  Executable ${exe} found: " $(which ${exe})
	fi
done


########################################################################
#Functions to config various interfaces - some are different
#Prototype: 	config_type phyX setchn setfreq

#Configure Intel iwlwifi based adapter
config_iwlwifi () {		
	
	phy=$1
	origname=$(ls /sys/class/ieee80211/${phy}/device/net/)
	phyndex=$(cat /sys/class/ieee80211/${phy}/index)
	echo "Configure iwlwifi at ${phy} / ${origname} with index ${phyndex}"
	iface="wlan${phyndex}"
	monface="mon${phyndex}"
	
	nmcli d set ${origname} managed off
	ip link set ${origname} down
	ip link set ${origname} name ${iface}
	iw dev ${iface} set type managed	
	iw phy ${phy} interface add ${monface} type monitor
	
	ip link set ${iface} up
	ip link set ${monface} up
	iw dev ${iface} scan
	#iw phy ${phy} reg get
	ip link set ${iface} down
}

#Configure general adapter
config_general () {		
	
	phy=$1
	origname=$(ls /sys/class/ieee80211/${phy}/device/net/)
	phyndex=$(cat /sys/class/ieee80211/${phy}/index)
	echo "Configure general driver at ${phy} / ${origname} with index ${phyndex}"
	iface="wlan${phyndex}"
	monface="mon${phyndex}"
	
	nmcli d set ${origname} managed off
	ip link set ${origname} down
	ip link set ${origname} name ${iface}
	sleep 1
	iw dev ${iface} set type monitor	
	
	ip link set ${iface} up
}

#Configure RPI BCM adapter - nexmon firmware requires special handling
config_rpibrcm () {	
	
	phy=$1
	origname=$(ls /sys/class/ieee80211/${phy}/device/net/)
	phyndex=$(cat /sys/class/ieee80211/${phy}/index)
	echo "Configure general driver at ${phy} / ${origname} with index ${phyndex}"
	iface="wlan${phyndex}"
	monface="mon${phyndex}"
	
	nmcli d set ${origname} managed off
	ip link set ${origname} down
	ip link set ${origname} name ${iface}
	
	iw phy ${phy} interface add ${monface} type monitor
	ip link set ${monface} up

	return
}

#Set channel or freq
config_channelfreq () {
	ic=$1
	if [ "${setchannel}" == 1 ]
	then
		iw phy ${ic} set channel ${chntoset}

	elif [ "${setfreq}" == 1 ]
	then
		iw phy ${ic} set freq ${freqtoset}
	fi	
}	

########################################################################
#Main Routine

#Display current state of adapters
echo "---------------------------------------------------------------------------------------------------------------"
echo "Starting interfaces configuration"
interfaces.sh

#Set regulatory domain
echo "---------------------------------------------------------------------------------------------------------------"
echo "Set regulatory domain"                                
iw reg set ${regdomain} && echo "iw reg set ${regdomain} ....... [OK]" || echo "iw reg set ${regdomain} ... [FAILED]"
iw reg get | sed -n '/global/,/^$/p' | sed 's/^/  /'


#Reset USB prior to enumerating adapters - sleep timers are empirical
#Watch dmesg output to see how long it takes for USB adapter to be recognized
#Mostly needed for Ath9170 USB adapters with the carl9170 driver
if [ "${resetusb}" == 1 ]
then
	echo "---------------------------------------------------------------------------------------------------------------"
	echo "Reset ykush USB device"
	ykushcmd ykushxs -d	
	sleep 3
	ykushcmd ykushxs -u
	sleep 8
fi	

#Populate array of adapters to process
adapters=()
if [ "$allphys" == 0 ]	#Single phy to process
then
	adapters=(${phyoption})
else
	adapters=$(ls /sys/class/ieee80211/)
fi
#echo "Adapters to process:"
#echo "${adapters[@]}" 	

if [ "${setchnonly}" == 0 ]
then
	#Loop through each adapter --> find driver, and call specific setup function
	#Set regulatory domain
	echo "---------------------------------------------------------------------------------------------------------------"
	echo "Configure adapter(s)"
	for i in ${adapters[@]}
	do
		name=$(ls /sys/class/ieee80211/${i}/device/net/)
		driver=$(ethtool -i ${name} | grep -i driver | awk '{print $2}')
		echo "Configuring adapter ${i} / ${name} / ${driver}"
		
		if [ "${driver}" == "iwlwifi" ]
		then
			config_iwlwifi  ${i}
		elif [ "${driver}" == "brcmfmac" ]
		then
			config_rpibrcm ${i} 
		else
			config_general  ${i}
		fi
		interfaces.sh
		sleep 2
	done
fi

echo "---------------------------------------------------------------------------------------------------------------"
echo "Monitor interface configuration"
interfaces.sh

echo "---------------------------------------------------------------------------------------------------------------"
echo "Set channel/frequency"
#Set channel or freq, as selected
for i in ${adapters[@]}
do
	config_channelfreq ${i}
done

echo "---------------------------------------------------------------------------------------------------------------"
echo "Final interface configuration"
interfaces.sh

exit 0

