#!/bin/bash 
set -x
uname -a
echo
lspci
echo
lspci -v 
echo
lsusb
echo
lsusb -t
echo
for phys in $(ls /sys/class/ieee80211/); do echo ${phys}; ethtool -i $(ls /sys/class/ieee80211/${phys}/device/net/ | head -1); echo;  done
echo
ip link
echo
ip dev
echo
iw reg get
echo 
iw list
echo
dmesg -T
echo
nmcli d
echo
interfaces.sh

# sudo ./sysdetails.sh > source.txt 2>&1
