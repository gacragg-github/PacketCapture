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
		strOUTPUT[$i]=$(printf "%s %9s" "${strOUTPUT[$i]}" "$packets")
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
		strOUTPUT[$i]=$(printf "%s %9s %6s" "${strOUTPUT[$i]}" "$packets" "$packetsdelta")
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
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %9s %6s %s\n" "${header[@]}"
else
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets Adapter)
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %9s %s\n" "${header[@]}"
fi
for i in "${strOUTPUT[@]}"
do
   echo -e "$i" 
done


#Block comments
: <<'END'
george@nms1:~/Documents$ ./interfaces.sh

Ndx      Iface   Phy       Driver      Mode   Up?         Channel Width      Packets
  0      wlan0  phy0    rt2800usb   monitor     Y     1 (2412MHz) 20MHz      3764007
  1      wlan1  phy1    ath9k_htc   monitor     Y     1 (2412MHz) 20MHz      3875317
  2      wlan6  phy3    ath9k_htc   monitor     Y     6 (2437MHz) 20MHz      7293112
  3     wlan11  phy2    ath9k_htc   monitor     Y    11 (2462MHz) 20MHz      8426692
  4     wlan36  phy5       8812au   monitor     Y    36 (5180MHz) 80MHz      8913971
  5    wlan149  phy4       8812au   monitor     Y   149 (5745MHz) 80MHz     14585200

  
  
root@airbud1:/home/admin/tools# ./interfaces.sh

Ndx      Iface   Phy       Driver      Mode   Up?         Channel Width     Center      Packets  Adapter
  0      wlan0  phy5    rt2800usb   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       305982  Ralink Technology, Corp. RT3573
  1      wlan2  phy0    rtl8192cu   monitor     Y     1 (2412MHz) 20MHz   2412 MHz          602  NetGear, Inc. WNA1000M 802.11bgn [Realtek RTL8188CUS]
  2      wlan3  phy8       8812au   monitor     Y     1 (2412MHz) 20MHz   2412 MHz        73933  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
  3      wlan5  phy3     carl9170   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       184319  NetGear, Inc. WNDA3100v1 802.11abgn [Atheros AR9170+AR9104]
  4      wlan6  phy4    ath9k_htc   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       234125  Atheros Communications, Inc. AR9271 802.11n
  5      wlan8  phy9    rt2800usb   monitor     Y     1 (2412MHz) 20MHz   2412 MHz        17466  Ralink Technology, Corp. RT5370
  6     wlan10  phy6      iwlwifi   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       238181  Intel Corporation Device 24fd (rev 78)
  7     wlan90  phy1        ath9k   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       379625  Qualcomm Atheros AR928X Wireless Network Adapter (PCI-Express) (rev 01)
  8     wlan91  phy7        ath9k   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       297366  Qualcomm Atheros AR928X Wireless Network Adapter (PCI-Express) (rev 01)
  9     wlan92 phy10        ath9k   monitor     Y     1 (2412MHz) 20MHz   2412 MHz       495096  Qualcomm Atheros AR928X Wireless Network Adapter (PCI-Express) (rev 01)
 10    wlan104  phy2   ath10k_pci   monitor     Y   149 (5745MHz) 80MHz   5775 MHz       188310  Qualcomm Atheros QCA986x/988x 802.11ac Wireless Network Adapter

  
admin@kaliVM:~/Documents$ ./interfaces.sh

Ndx      Iface   Phy       Driver      Mode   Up?         Channel Width      Packets
  0      wlan0  phy0      iwlwifi   monitor     Y   149 (5745MHz) 80MHz       907986
  1      wlan1  phy2    rt2800usb   monitor     Y     1 (2412MHz) 20MHz       231104
  2      wlan6  phy1    rt2800usb   monitor     Y     6 (2437MHz) 20MHz         7996
  3     wlan11  phy3    rt2800usb   monitor     Y    11 (2462MHz) 20MHz       438530

[george@server Documents]$ ./interfaces.sh

Ndx      Iface   Phy       Driver      Mode   Up?         Channel Width      Packets
  0     wlp1s0  phy0    rt2800pci   managed     Y                                  0

 
admin1@dinm9:~/software/injection$ sudo ./interfaces.sh -d 3
[CONFIG] deltaperiod set to argument 3
Calculating delta packets...3...2...1...
[DEBUG] packets: 12185972, pkts_0: 12185881, deltaP: 91
[DEBUG] packets: 0, pkts_0: 0, deltaP: 0
[DEBUG] packets: 12694106, pkts_0: 12693937, deltaP: 169
[DEBUG] packets: 9878849, pkts_0: 9878730, deltaP: 119
[DEBUG] packets: 10056459, pkts_0: 10056316, deltaP: 143
[DEBUG] packets: 12174753, pkts_0: 12174593, deltaP: 160
[DEBUG] packets: 12619865, pkts_0: 12619701, deltaP: 164
[DEBUG] packets: 12266408, pkts_0: 12266243, deltaP: 165
[DEBUG] packets: 12106160, pkts_0: 12105997, deltaP: 163
[DEBUG] packets: 10030207, pkts_0: 10030095, deltaP: 112
[DEBUG] packets: 12320844, pkts_0: 12320684, deltaP: 160
[DEBUG] packets: 3993749, pkts_0: 3993628, deltaP: 121

Ndx     Iface   Phy       Driver       Mode  Up       Channel  Width   Center   Packets DeltaP Adapter
  0       mon0  phy0      iwlwifi   monitor   Y 100 (5500MHz) 160MHz 5570 MHz  12185972     91  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  1      wlan0  phy0      iwlwifi   managed   N                                       0      0  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  2      wlan1  phy1    rtl88XXau   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12694106    169  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
  3      wlan2  phy2     carl9170   monitor   Y   6 (2437MHz)  20MHz 2437 MHz   9878849    119  CACE Technologies Inc. AirPcap NX [Atheros AR9170+AR9104]
  4      wlan3  phy3    rtl88XXau   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  10056459    143  Realtek Semiconductor Corp. RTL8814AU 802.11a/b/g/n/ac
  5      wlan4  phy4      mt76x2u   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12174753    160  MediaTek Inc. MT7612U 802.11a/b/g/n/ac
  6      wlan5  phy5      mt7921u   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12619865    164  MediaTek Inc. Wireless_Device
  7      wlan6  phy6    ath9k_htc   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12266408    165  Qualcomm Atheros Communications AR9271 802.11n
  8      wlan7  phy7    rt2800usb   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12106160    163  Ralink Technology, Corp. RT5370
  9      wlan8  phy8    rt2800usb   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  10030207    112  Ralink Technology, Corp. RT5372
 10      wlan9  phy9    rt2800usb   monitor   Y   6 (2437MHz)  20MHz 2437 MHz  12320844    160  NetGear, Inc. WNDA4100 802.11abgn 3x3:3 [Ralink RT3573]
 11     wlan10 phy10     carl9170   monitor   Y   6 (2437MHz)  20MHz 2437 MHz   3993749    121  Qualcomm Atheros Communications AR9170 802.11n
 
  
END



