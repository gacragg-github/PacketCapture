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
#				1		08/2026		Require -x to make changes (bare/-x-less invocation just
#								prints help); idempotent per-adapter - a phy already in
#								monitor mode is left alone and reported, not reconfigured.
#				2		08/2026		Idempotency also covers channel/freq: only newly
#								(re)configured adapters get retuned, so a repeat run no
#								longer resets an already-monitor-mode phy's channel back
#								to the default. -r still retunes all selected adapters,
#								since that's its whole purpose.
#				3		08/2026		Fixed ethtool -i getting two interface names (and thus
#								failing) on phys with a separate monitor sibling - now
#								uses the monitor interface when one exists. Added -F to
#								print each adapter's firmware version (ethtool -i).
#				4		08/2026		-F alone (no -x) is now a read-only report and needs
#								neither -x nor root, since it only queries state.
#
#	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.




#iw/ethtool live in /usr/sbin, which isn't on a non-root user's PATH - needed since -F
#(read-only) is meant to run without sudo
export PATH="${PATH}:/usr/sbin:/sbin"

#Defaults
regdomain="KR"
chndefault="6 HT20"
freqdefault="6935 160 6985"
setchnonly=0
resetusb=0
showfirmware=0

#Help
usage () {
	echo "Configure adapters for monitor mode"
	echo "Usage: $0 -x [-i phyX] [-c 'channel string'] [-f 'freq string']"
	echo "Options:"
	echo -e "  -x                   Execute the reconfiguration (required; without it, this help is shown and nothing is changed)"
	echo -e "  -h                   help"
	echo -e "  -i phyX              phy to convert   Default: all"
	echo -e "  -c 'channel string'  Channel config   Default: '${chndefault}' (priority)"
	echo -e "  -f 'freq string'     Freq config      Default: '${freqdefault}'"
	echo -e "  -r                   Only set channel/freq"
	echo -e "  -y                   Reset ykush USB"
	echo -e "  -F                   Print firmware version (from ethtool -i) for each adapter - read-only, works without -x"
	echo -e	"  -d                   debug"
	echo
	echo "Idempotent: a phy already in monitor mode is left alone on a repeat run - reported, not reconfigured."
}

#Does phy index $1 already have an interface up in monitor mode? Echoes its name if so.
#Defined this early so the read-only -F report (below, no -x/root needed) can use it.
phy_has_monitor () {
	local target_idx=$1 ifc wiphy mode
	for ifc in $(iw dev | awk '/Interface/ {print $2}')
	do
		wiphy=$(iw dev "${ifc}" info 2>/dev/null | awk '/wiphy/ {print $2}')
		[ "${wiphy}" == "${target_idx}" ] || continue
		mode=$(iw dev "${ifc}" info 2>/dev/null | awk '/type/ {print $2}')
		if [ "${mode}" == "monitor" ]
		then
			echo "${ifc}"
			return 0
		fi
	done
	return 1
}


########################################################################
#Option handling

execute=0
while getopts "h?xvi:c:f:ryFd" opt; do
  case "$opt" in
    h|\?)
      usage
      exit 0
      ;;
    x)  execute=1
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
    F)	showfirmware=1
      ;;
    d)	set -x
      ;;
  esac
done

#-F alone is a read-only report (just ethtool -i/iw queries) - it needs neither -x nor root
if [ "${showfirmware}" == 1 ] && [ "${execute}" != 1 ]
then
	for i in $(ls /sys/class/ieee80211/)
	do
		phyndex=$(cat /sys/class/ieee80211/${i}/index)
		monif=$(phy_has_monitor "${phyndex}")
		if [ -n "${monif}" ]
		then
			name="${monif}"
		else
			name=$(ls /sys/class/ieee80211/${i}/device/net/ | head -n1)
		fi
		ethinfo=$(ethtool -i ${name} 2>/dev/null)
		driver=$(echo "${ethinfo}" | awk '/^driver:/ {print $2}')
		firmware=$(echo "${ethinfo}" | sed -n 's/^firmware-version:[[:space:]]*//p')
		if [ -n "${monif}" ]
		then
			echo "${i} / ${name} / ${driver}: fw ${firmware} (monitor mode)"
		else
			echo "${i} / ${name} / ${driver}: fw ${firmware}"
		fi
	done
	exit 0
fi

#Without -x (including a bare invocation with no options at all), just show help and do nothing
if [ "${execute}" != 1 ]
then
	usage
	exit 0
fi

#Check for elevated privileges
if [[ $(id -u) -ne 0 ]]
then
	echo "Please run with elevated privileges"
	usage
	exit 1
fi

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
	newly_configured=()
	for i in ${adapters[@]}
	do
		phyndex=$(cat /sys/class/ieee80211/${i}/index)
		monif=$(phy_has_monitor "${phyndex}")

		#Prefer the monitor-mode interface for reporting - a phy can have more than one
		#net interface (e.g. iwlwifi keeps the original alongside the monitor sibling it adds),
		#and ethtool -i only accepts a single interface name.
		if [ -n "${monif}" ]
		then
			name="${monif}"
		else
			name=$(ls /sys/class/ieee80211/${i}/device/net/ | head -n1)
		fi
		ethinfo=$(ethtool -i ${name} 2>/dev/null)
		driver=$(echo "${ethinfo}" | awk '/^driver:/ {print $2}')
		firmware=$(echo "${ethinfo}" | sed -n 's/^firmware-version:[[:space:]]*//p')

		fwsuffix=""
		if [ "${showfirmware}" == 1 ]
		then
			fwsuffix=" (fw: ${firmware})"
		fi

		if [ -n "${monif}" ]
		then
			echo "Adapter ${i} / ${name} / ${driver}${fwsuffix}: already in monitor mode (${monif}) - no change made"
		else
			echo "Configuring adapter ${i} / ${name} / ${driver}${fwsuffix}"
			if [ "${driver}" == "iwlwifi" ]
			then
				config_iwlwifi  ${i}
			elif [ "${driver}" == "brcmfmac" ]
			then
				config_rpibrcm ${i}
			else
				config_general  ${i}
			fi
			sleep 2
			newly_configured+=("${i}")
		fi
		interfaces.sh
	done
fi

echo "---------------------------------------------------------------------------------------------------------------"
echo "Monitor interface configuration"
interfaces.sh

echo "---------------------------------------------------------------------------------------------------------------"
echo "Set channel/frequency"
#Set channel or freq, as selected - but only for adapters actually (re)configured this run.
#With -r (setchnonly), there was no configure step at all, so retune whatever was asked for on all of them.
#Otherwise, leave already-in-monitor-mode adapters alone - idempotent means their channel isn't touched either.
if [ "${setchnonly}" == 1 ]
then
	chanadapters=(${adapters[@]})
else
	chanadapters=(${newly_configured[@]})
fi

if [ "${#chanadapters[@]}" -eq 0 ]
then
	echo "No adapters to set - all already in monitor mode, no change made"
else
	for i in ${chanadapters[@]}
	do
		config_channelfreq ${i}
	done
fi

echo "---------------------------------------------------------------------------------------------------------------"
echo "Final interface configuration"
interfaces.sh

exit 0

