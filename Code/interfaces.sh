#!/bin/bash

#Protoype:
#
# ./interfaces.sh [options]
#
#Rollup interface wireless interface data.  Target output:
#Ndx      Iface   Phy     Driver          Mode            Up?     Channel         Width   Packets
#0        wlan1   phy2    rt2800usb       monitor         Y       1 (2412MHz)     20MHz   156883
#1        wlan0   phy0    iwlwifi         monitor         Y       149 (5745MHz)   80MHz   682995
#2        wlan11  phy3    rt2800usb       monitor         Y       11 (2462MHz)    20MHz   274373
#3        wlan6   phy1    rt2800usb       monitor         Y       6 (2437MHz)     20MHz   4629
#
#Maintainer: G. Cragg, gacragg@gmail.com
#Version	Date		Notes
#0			Oct 2017	Release - note bug that if HT not enabled, output will be partially garbled
#						So set interface to do HT, such as  
#							iw dev wlp1s0 set channel 6 HT20
#							iw dev wlp1s0 set channel 1 HT40+
#0.1		Nov 2017	Added adapter ID from airmon-ng output
#0.2		Nov 2022	Add delta packets capability to detect hung adapter



#Defaults
deltaperioddefault=3
debug=false

#Help
usage () {
	echo "Describe wireless interfaces"
	echo "Usage: $0 [-d xxx]"
	echo "Options: (all optional)"
	echo -e "  -h                   Help"
	echo -e	"  -d <xxx>             Display delta packet count over xxx period of sec"
}


#Check for elevated privileges
if [[ $(id -u) -ne 0 ]]
then 
	echo "Note: More information is available with elevated privileges"
	echo
	#usage
	#exit 1
fi


########################################################################
#Option handling

while getopts "h?d:" opt; do
	case "$opt" in
		h|\?)
			usage
			exit 0
		;;
		d)
			if [ $OPTARG -eq $OPTARG 2>/dev/null -o $OPTARG -eq 0 2>/dev/null ]
			then
				deltaperiod=$OPTARG
				if [ "${debug}" = true ]; then echo "[CONFIG] deltaperiod set to argument ${deltaperiod}"; fi
			else
				deltaperiod=${deltaperioddefault}
				if [ "${debug}" = true ]; then echo "[CONFIG] deltaperiod set to default ${deltaperiod}"; fi 
			fi
			calcdeltapkts=true
        ;;
	esac
done


#Print an array of information
function PrintArray() {

	InputArray=("$@")
	echo "Array items:"
	for item in ${InputArray[@]}
	do
		printf "   %s\n" $item
	done
}
#Prototype:
#	echo "Print whole array"
#	PrintArray "${array[@]}"



#Get Interfaces
#IFACES=($(cat /proc/net/dev | grep wlan | awk -F":" '{print $1}' | sort -V)) #<-- doesn't seem to sort correctly
IFACES=($(/sbin/iw dev | awk '/Interface/ {print $2}' | sort -V))
strOUTPUT=IFACES
WIPHY=()


#With interfaces, assign arbitrary index for each one
for i in "${!IFACES[@]}"
do
   #strOUTPUT[$i]="$i\t ${IFACES[$i]}"
   strOUTPUT[$i]=$(printf "%3s %10s\n" "$i" "${IFACES[$i]}")	
done


#Find phy ID for each interface
for i in "${!IFACES[@]}"
do
   phyID=$(/sbin/iw dev ${IFACES[$i]} info | awk '/wiphy/ {print $2}')
   WIPHY[$i]=phy$phyID	
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t ${WIPHY[$i]}"
   strOUTPUT[$i]=$(printf "%s %5s" "${strOUTPUT[$i]}" "${WIPHY[$i]}")	
done


#Find driver for each device
for i in "${!IFACES[@]}"
do
   driver=$(/sbin/ethtool -i ${IFACES[$i]} | awk '/driver/ {print $2}')
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t $driver"
   strOUTPUT[$i]=$(printf "%s %12s" "${strOUTPUT[$i]}" "$driver")		
done


#Find Mode for each device
for i in "${!IFACES[@]}"
do
   mode=$(/sbin/iw dev ${IFACES[$i]} info | awk '/type/ {print $2}')
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t $mode"
   strOUTPUT[$i]=$(printf "%s %9s" "${strOUTPUT[$i]}" "$mode")	
done


#Find if interface is UP
for i in "${!IFACES[@]}"
do
   unset intUP
   intUP=$(/sbin/ifconfig ${IFACES[$i]} | grep UP)
   if [ -z "$intUP" ]; then
	Status="N"
   else
	Status="Y"
   fi
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t $Status"
   strOUTPUT[$i]=$(printf "%s %3s" "${strOUTPUT[$i]}" "$Status")	
done


#Get Channel(Freq) and bandwidth
for i in "${!IFACES[@]}"
do
   channel=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print$2" "$3$4}' | sed 's/,$//')
   bandwidth=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print $6$7}' | sed 's/,$//')
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t $channel\t $bandwidth"
   strOUTPUT[$i]=$(printf "%s %13s %6s" "${strOUTPUT[$i]}" "$channel" "$bandwidth")	
done


#Get center frequency to tell us if we are HT40+, HT40-, etc.  Shows extension channel set.
for i in "${!IFACES[@]}"
do
   center=$(/sbin/iw dev ${IFACES[$i]} info | awk '/center1/ { print $9" "$10}')
   #strOUTPUT[$i]="${strOUTPUT[$i]}\t $center"	
   strOUTPUT[$i]=$(printf "%s %8s" "${strOUTPUT[$i]}" "$center")
done

#Get packets seen on the interface
rxpkts_0=()		#Initial packet count array
for i in "${!IFACES[@]}"
do
	packets=$(/sbin/ifconfig ${IFACES[$i]} | awk '/RX packets/ {print $3}')
	rxpkts_0[$i]+=${packets}
	if [ ! "${calcdeltapkts}" = true ]
	then
		strOUTPUT[$i]=$(printf "%s %10s" "${strOUTPUT[$i]}" "$packets")
	fi 
done


#If calculating delta packets, run through packet count again and do the math after the delay
if [ "${calcdeltapkts}" = true ]
then
	echo -n "Calculating delta packets..."
	while [ ${deltaperiod} -gt 0 ]
	do
		echo -n "${deltaperiod}..."
		sleep 1
		: $((deltaperiod--))
	done
	echo
	for i in "${!IFACES[@]}"
	do
		packets=$(/sbin/ifconfig ${IFACES[$i]} | awk '/RX packets/ {print $3}')
		packetsdelta=$(($packets-${rxpkts_0[$i]}))
		if [ "${debug}" = true ]; then echo "[DEBUG] packets: ${packets}, pkts_0: ${rxpkts_0[$i]}, deltaP: ${packetsdelta}"; fi
		strOUTPUT[$i]=$(printf "%s %10s %6s" "${strOUTPUT[$i]}" "$packets" "$packetsdelta")
	done
fi



#Execute airmon-ng once (slow, and requires root)
#Save this to an array and then just print array and use std tools to 
#extract adapter we need
IFS=$'\n'
array=($(airmon-ng | grep phy))

#Get adapter name through lsusb or lspci <- screenscarape from airmon-ng.  Will need to be root.
for i in "${!IFACES[@]}"
do
   adapter=$(PrintArray "${array[@]}" | grep -w "${IFACES[$i]}" | awk -F "\t" '{print $5$6}') 
   strOUTPUT[$i]=$(printf "%s  %s" "${strOUTPUT[$i]}" "$adapter")
done


#Print items - total table
echo
#echo -e "Ndx\t Iface\t Phy\t Driver\t\t Mode\t\t  Up\t Channel\t Width\t Packets\t Adapter"

if [ "${calcdeltapkts}" = true ]
then
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets DeltaP Adapter)
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %10s %6s  %s\n" "${header[@]}"
else
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets Adapter)
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %10s  %s\n" "${header[@]}"
fi
for i in "${strOUTPUT[@]}"
do
   echo -e "$i" 
done


#Block comments
: <<'END'
END



