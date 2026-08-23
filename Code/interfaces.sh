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
# 0.4		Aug 2026	Dynamic column widths sized to actual data instead of
#				fixed printf widths, so the table doesn't waste space
#				on short values or clip long ones.
# 0.5		Aug 2026	Add -a to cap the Adapter column width for narrow
#				terminals (it's the one column with no natural bound).

deltaperioddefault=3
debug=false

usage () {
	echo "Describe wireless interfaces"
	echo "Usage: $0 [-d xxx] [-a xxx]"
	echo -e "  -h                   Help"
	echo -e "  -d <xxx>             Display delta packet count over xxx period of sec"
	echo -e "  -a <xxx>             Limit the Adapter column to xxx characters (overrides its dynamic width)"
}

if [[ $(id -u) -ne 0 ]]; then echo "Note: More information is available with elevated privileges"; echo; fi

while getopts "h?d:a:" opt; do
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
		a)
			if [ $OPTARG -eq $OPTARG 2>/dev/null ] && [ $OPTARG -gt 0 ]; then
				adapterwidth=$OPTARG
			fi
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

# Width of the widest of a column header and its values
colwidth() {
	local w=${#1} v
	shift
	for v in "$@"; do
		(( ${#v} > w )) && w=${#v}
	done
	echo "$w"
}

# Interfaces (iw)
IFACES=($(/sbin/iw dev | awk '/Interface/ {print $2}' | sort -V))
WIPHY=()
DRIVER=()
MODE=()
UP=()
CHANNEL=()
WIDTH=()
CENTER=()
PACKETS=()
DELTAP=()
ADAPTER=()

# Phy (iw)
for i in "${!IFACES[@]}"; do
	phyID=$(/sbin/iw dev ${IFACES[$i]} info | awk '/wiphy/ {print $2}')
	WIPHY[$i]=phy$phyID
done

# Driver (/sys, was ethtool -i)
for i in "${!IFACES[@]}"; do
	DRIVER[$i]=$(basename "$(readlink -f /sys/class/net/${IFACES[$i]}/device/driver 2>/dev/null)" 2>/dev/null)
done

# Mode (iw)
for i in "${!IFACES[@]}"; do
	MODE[$i]=$(/sbin/iw dev ${IFACES[$i]} info | awk '/type/ {print $2}')
done

# Up? (/sys flags bit0 IFF_UP, was ifconfig|grep UP)
for i in "${!IFACES[@]}"; do
	f=$(cat /sys/class/net/${IFACES[$i]}/flags 2>/dev/null)
	if [ $(( ${f:-0} & 1 )) -eq 1 ]; then UP[$i]="Y"; else UP[$i]="N"; fi
done

# Channel(Freq) + bandwidth (iw)
for i in "${!IFACES[@]}"; do
	CHANNEL[$i]=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print $2"/"$3$4}' | sed 's/[(),]//g')
	WIDTH[$i]=$(/sbin/iw ${IFACES[$i]} info | awk '/channel/ {print $0}' | awk -F" " '{print $6$7}' | sed 's/,$//')
done

# Center freq (iw)
for i in "${!IFACES[@]}"; do
	CENTER[$i]=$(/sbin/iw dev ${IFACES[$i]} info | awk '/center1/ { print $9$10}')
done

# Packets (/sys, was ifconfig RX packets)
rxpkts_0=()
for i in "${!IFACES[@]}"; do
	packets=$(cat /sys/class/net/${IFACES[$i]}/statistics/rx_packets 2>/dev/null)
	rxpkts_0[$i]+=${packets}
	if [ ! "${calcdeltapkts}" = true ]; then
		PACKETS[$i]=${packets}
	fi
done

if [ "${calcdeltapkts}" = true ]; then
	echo -n "Calculating delta packets..."
	while [ ${deltaperiod} -gt 0 ]; do echo -n "${deltaperiod}..."; sleep 1; : $((deltaperiod--)); done
	echo
	for i in "${!IFACES[@]}"; do
		packets=$(cat /sys/class/net/${IFACES[$i]}/statistics/rx_packets 2>/dev/null)
		PACKETS[$i]=${packets}
		DELTAP[$i]=$(($packets-${rxpkts_0[$i]}))
	done
fi

# Adapter name (lspci/lsusb, was airmon-ng)
for i in "${!IFACES[@]}"; do
	ADAPTER[$i]=$(get_adapter "${IFACES[$i]}")
	if [ -n "${adapterwidth}" ]; then
		ADAPTER[$i]="${ADAPTER[$i]:0:$adapterwidth}"
	fi
done

# Column widths sized to the widest header/value actually present this run
NDX=("${!IFACES[@]}")
W_NDX=$(colwidth Ndx "${NDX[@]}")
W_IFACE=$(colwidth Iface "${IFACES[@]}")
W_PHY=$(colwidth Phy "${WIPHY[@]}")
W_DRIVER=$(colwidth Driver "${DRIVER[@]}")
W_MODE=$(colwidth Mode "${MODE[@]}")
W_UP=$(colwidth Up "${UP[@]}")
W_CHANNEL=$(colwidth Channel "${CHANNEL[@]}")
W_WIDTH=$(colwidth Width "${WIDTH[@]}")
W_CENTER=$(colwidth Center "${CENTER[@]}")
W_PACKETS=$(colwidth Packets "${PACKETS[@]}")

FMT="%${W_NDX}s %${W_IFACE}s %${W_PHY}s %${W_DRIVER}s %${W_MODE}s %${W_UP}s %${W_CHANNEL}s %${W_WIDTH}s %${W_CENTER}s %${W_PACKETS}s"
if [ "${calcdeltapkts}" = true ]; then
	W_DELTAP=$(colwidth DeltaP "${DELTAP[@]}")
	FMT="${FMT} %${W_DELTAP}s"
fi
FMT="${FMT}  %s\n"

echo
if [ "${calcdeltapkts}" = true ]; then
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets DeltaP Adapter)
else
	header=(Ndx Iface Phy Driver Mode Up Channel Width Center Packets Adapter)
fi
printf "$FMT" "${header[@]}"

for i in "${!IFACES[@]}"; do
	if [ "${calcdeltapkts}" = true ]; then
		printf "$FMT" "$i" "${IFACES[$i]}" "${WIPHY[$i]}" "${DRIVER[$i]}" "${MODE[$i]}" "${UP[$i]}" "${CHANNEL[$i]}" "${WIDTH[$i]}" "${CENTER[$i]}" "${PACKETS[$i]}" "${DELTAP[$i]}" "${ADAPTER[$i]}"
	else
		printf "$FMT" "$i" "${IFACES[$i]}" "${WIPHY[$i]}" "${DRIVER[$i]}" "${MODE[$i]}" "${UP[$i]}" "${CHANNEL[$i]}" "${WIDTH[$i]}" "${CENTER[$i]}" "${PACKETS[$i]}" "${ADAPTER[$i]}"
	fi
done
