#!/bin/bash
# Rollup wireless interface data (dependency-reduced).
# Maintainer: G. Cragg, gacragg@gmail.com
# Version	Date		Notes
# 0		Oct 2017	Release
# 0.1		Nov 2017	Added adapter ID from airmon-ng output
# 0.2		Nov 2022	Add delta packets to detect hung adapter
# 0.3		Aug 2026	Remove aircrack-ng/ethtool/net-tools deps: driver via /sys,
#				up via /sys flags, rx via /sys statistics, adapter via
#				lspci/lsusb (was airmon-ng). Keeps iw + pciutils/usbutils.

deltaperioddefault=3
debug=false

usage () {
	echo "Describe wireless interfaces"
	echo "Usage: $0 [-d xxx]"
	echo -e "  -h                   Help"
	echo -e "  -d <xxx>             Display delta packet count over xxx period of sec"
}

if [[ $(id -u) -ne 0 ]]; then echo "Note: More information is available with elevated privileges"; echo; fi

while getopts "h?d:" opt; do
	case "$opt" in
		h|\?) usage; exit 0 ;;
		d)
			if [ $OPTARG -eq $OPTARG 2>/dev/null -o $OPTARG -eq 0 2>/dev/null ]; then
				deltaperiod=$OPTARG
			else
				deltaperiod=${deltaperioddefault}
			fi
			calcdeltapkts=true
		;;
	esac
done

# Adapter human name via lspci/lsusb (replaces airmon-ng screen-scrape)
get_adapter() {
	local IF="$1" dev bus a d vid pid
	dev="/sys/class/net/$IF/device"
	bus=$(basename "$(readlink -f "$dev/subsystem" 2>/dev/null)" 2>/dev/null)
	if [ "$bus" = pci ]; then
		a=$(basename "$(readlink -f "$dev" 2>/dev/null)")
		lspci -s "$a" 2>/dev/null | sed -E 's/^[0-9a-f:.]+ [^:]+: //'
	elif [ "$bus" = usb ]; then
		d=$(readlink -f "$dev" 2>/dev/null)
		while [ -n "$d" ] && [ ! -e "$d/idVendor" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
		vid=$(cat "$d/idVendor" 2>/dev/null); pid=$(cat "$d/idProduct" 2>/dev/null)
		[ -n "$vid" ] && lsusb -d "$vid:$pid" 2>/dev/null | sed -E 's/^Bus.*ID [0-9a-f:]+ //'
	fi
}

# Interfaces (iw)
IFACES=($(/sbin/iw dev | awk '/Interface/ {print $2}' | sort -V))
strOUTPUT=IFACES
WIPHY=()

for i in "${!IFACES[@]}"; do
	strOUTPUT[$i]=$(printf "%3s %10s\n" "$i" "${IFACES[$i]}")
done

# Phy (iw)
for i in "${!IFACES[@]}"; do
	phyID=$(/sbin/iw dev ${IFACES[$i]} info | awk '/wiphy/ {print $2}')
	WIPHY[$i]=phy$phyID
	strOUTPUT[$i]=$(printf "%s %5s" "${strOUTPUT[$i]}" "${WIPHY[$i]}")
done

# Driver (/sys, was ethtool -i)
for i in "${!IFACES[@]}"; do
	driver=$(basename "$(readlink -f /sys/class/net/${IFACES[$i]}/device/driver 2>/dev/null)" 2>/dev/null)
	strOUTPUT[$i]=$(printf "%s %12s" "${strOUTPUT[$i]}" "$driver")
done

# Mode (iw)
for i in "${!IFACES[@]}"; do
	mode=$(/sbin/iw dev ${IFACES[$i]} info | awk '/type/ {print $2}')
	strOUTPUT[$i]=$(printf "%s %9s" "${strOUTPUT[$i]}" "$mode")
done

# Up? (/sys flags bit0 IFF_UP, was ifconfig|grep UP)
for i in "${!IFACES[@]}"; do
	f=$(cat /sys/class/net/${IFACES[$i]}/flags 2>/dev/null)
	if [ $(( ${f:-0} & 1 )) -eq 1 ]; then Status="Y"; else Status="N"; fi
	strOUTPUT[$i]=$(printf "%s %3s" "${strOUTPUT[$i]}" "$Status")
done

# Channel(Freq) + bandwidth (iw)
for i in "${!IFACES[@]}"; do
	channel=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print$2" "$3$4}' | sed 's/,$//')
	bandwidth=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print $6$7}' | sed 's/,$//')
	strOUTPUT[$i]=$(printf "%s %13s %6s" "${strOUTPUT[$i]}" "$channel" "$bandwidth")
done

# Center freq (iw)
for i in "${!IFACES[@]}"; do
	center=$(/sbin/iw dev ${IFACES[$i]} info | awk '/center1/ { print $9" "$10}')
	strOUTPUT[$i]=$(printf "%s %8s" "${strOUTPUT[$i]}" "$center")
done

# Packets (/sys, was ifconfig RX packets)
rxpkts_0=()
for i in "${!IFACES[@]}"; do
	packets=$(cat /sys/class/net/${IFACES[$i]}/statistics/rx_packets 2>/dev/null)
	rxpkts_0[$i]+=${packets}
	if [ ! "${calcdeltapkts}" = true ]; then
		strOUTPUT[$i]=$(printf "%s %11s" "${strOUTPUT[$i]}" "$packets")
	fi
done

if [ "${calcdeltapkts}" = true ]; then
	echo -n "Calculating delta packets..."
	while [ ${deltaperiod} -gt 0 ]; do echo -n "${deltaperiod}..."; sleep 1; : $((deltaperiod--)); done
	echo
	for i in "${!IFACES[@]}"; do
		packets=$(cat /sys/class/net/${IFACES[$i]}/statistics/rx_packets 2>/dev/null)
		packetsdelta=$(($packets-${rxpkts_0[$i]}))
		strOUTPUT[$i]=$(printf "%s %11s %6s" "${strOUTPUT[$i]}" "$packets" "$packetsdelta")
	done
fi

# Adapter name (lspci/lsusb, was airmon-ng)
for i in "${!IFACES[@]}"; do
	adapter=$(get_adapter "${IFACES[$i]}")
	strOUTPUT[$i]=$(printf "%s  %s" "${strOUTPUT[$i]}" "$adapter")
done

echo
if [ "${calcdeltapkts}" = true ]; then
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets DeltaP Adapter)
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %11s %6s  %s\n" "${header[@]}"
else
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets Adapter)
	printf "%3s %9s %5s %12s %10s %3s %13s %6s %8s %11s  %s\n" "${header[@]}"
fi
for i in "${strOUTPUT[@]}"; do echo -e "$i"; done
