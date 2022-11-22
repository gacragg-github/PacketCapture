#!/usr/bin/env python3
#
#	Protoype: CaptureTestVx.py [options]
#
#	Inject various 802.11 frame types to test monitor-mode pickup capability from other adapters
#	Not all adapters have same injection capability, not all adapters have same Rx capability
#		and not all devices have monitor mode support
#
#	Requires
#		1. Scapy
#		2. Run as root or via sudo
#		3. Injection adapter in monitor mode
#
#
#		Example to inject via all interfaces that start with wl* or mon*:
#		root@nms2:~/software# for iface in $(ls /sys/class/net/ | grep -e wl -e mon); do ./CaptureTestV0.py -i $iface -m 'ALL'; done
#		root@nms2:~/software# ./CaptureTestV0.py -m 'HT40' -i 
#
#		References
#		1. https://research.securitum.com/generating-wifi-communication-in-scapy-tool/
#		2. http://www.cs.toronto.edu/~arnold/427/18s/427_18S/indepth/scapy_wifi/scapy_tut.html
#		3. https://github.com/secdev/scapy/blob/master/scapy/layers/dot11.py
#		4. scapy>>> ls(RadioTap)
#		5. https://docs.kernel.org/networking/mac80211-injection.html


import binascii
from scapy.all import *
print("scapy version in use: " + scapy.__version__)
import argparse


#---------------------------------------------------------------------------------
# Parse arguments
#---------------------------------------------------------------------------------
cliargs = argparse.ArgumentParser(description='Scapy test tool to inject 802.11 frames')
cliargs.add_argument('-i', action='store', default="mon0", dest='iface', help='Injection interface - should be in monitor mode')
cliargs.add_argument('-m', action='store', default="ALL", dest='modrequested', help='Modulation requested default: \'All\'')
cliargs.add_argument('-d', action='store_true', default=False, dest='displaymods', help='Display modulations available')
clioptions=cliargs.parse_args()


#Read injection interface from CLI
print(clioptions)


#Name various fields in the injected frames to match the interface used for identification
SSID = clioptions.iface

#Hardcoded parameters to use throughout injection exercise
srcmac = '01:23:45:67:89:ab'
#srcmac = RandMAC()


#Add information element
vsie = bytearray(b'\x00\x01\x02\x03 ')
vsie.extend(clioptions.iface.encode("utf-8"))


#Array of packets to inject
packets = []

#Setup functions to build the various 802.11 frame types
#	Modulation is one of:
#		1. abg		--> 24Mbs
#		2. HTxSS20	HT/xSS/20MHz/SGI --> x=1/72.2, x=2/144.4, x=3/216.7 	
#		3. HTxSS40	HT/xSS/40MHz/SGI --> x=1/150, x=2/300, x=3/450
#		4. VHT8		2SS/SGI/MCS8 --> 780Mbps
#		5. VHT9		2SS/SGI/MCS9 --> 867Mbps
#		6. HE		TBD
radiomodulation = {
	'abg': RadioTap(present='Rate', Rate=24), 
	'HT1SS20': RadioTap(present='MCS', knownMCS=7, MCS_index=7, MCS_bandwidth=0, guard_interval=1),
	'HT1SS20LDPC': RadioTap(present='MCS', knownMCS=95, MCS_index=7, MCS_bandwidth=0, guard_interval=1, FEC_type=1),
	'HT2SS20': RadioTap(present='MCS', knownMCS=7, MCS_index=15, MCS_bandwidth=0, guard_interval=1),
	'HT3SS20': RadioTap(present='MCS', knownMCS=7, MCS_index=23, MCS_bandwidth=0, guard_interval=1),
	'HT1SS40': RadioTap(present='MCS', knownMCS=7, MCS_index=7, MCS_bandwidth=1, guard_interval=1),
	'HT2SS40': RadioTap(present='MCS', knownMCS=7, MCS_index=15, MCS_bandwidth=1, guard_interval=1),
	'HT3SS40': RadioTap(present='MCS', knownMCS=7, MCS_index=23, MCS_bandwidth=1, guard_interval=1),
	'HT2SS40LDPC': RadioTap(present='MCS', knownMCS=95, MCS_index=15, MCS_bandwidth=1, guard_interval=1, FEC_type=1),
	'HT3SS40LDPC': RadioTap(present='MCS', knownMCS=95, MCS_index=23, MCS_bandwidth=1, guard_interval=1, FEC_type=1),
	'VHT81SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x81'),
	'VHT91SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x91'),
	'VHT82SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x82'),
	'VHT92SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x92'),
	'VHT83SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x83'),
	'VHT93SS': RadioTap(present='VHT', KnownVHT=69, PresentVHT=69, guard_interval=1, VHT_bandwidth=4, mcs_nss=b'\x93'),
	'HE': RadioTap(present='HE', he_data1=51196, he_data2=126, he_data3=10587, he_data4=0, he_data5=8338, he_data6=32514)
}


#Frame types
# 802.11-2016 9.2.4.1.3
_dot11_subtypes = {
		0: {  # Management
				0: "Association Request",
				1: "Association Response",
				2: "Reassociation Request",
				3: "Reassociation Response",
				4: "Probe Request",
				5: "Probe Response",
				6: "Timing Advertisement",
				8: "Beacon",
				9: "ATIM",
				10: "Disassociation",
				11: "Authentication",
				12: "Deauthentication",
				13: "Action",
				14: "Action No Ack",
		},
		1: {  # Control
				2: "Trigger",
				3: "TACK",
				4: "Beamforming Report Poll",
				5: "VHT/HE NDP Announcement",
				6: "Control Frame Extension",
				7: "Control Wrapper",
				8: "Block Ack Request",
				9: "Block Ack",
				10: "PS-Poll",
				11: "RTS",
				12: "CTS",
				13: "Ack",
				14: "CF-End",
				15: "CF-End+CF-Ack",
		},
		2: {  # Data
				0: "Data",
				1: "Data+CF-Ack",
				2: "Data+CF-Poll",
				3: "Data+CF-Ack+CF-Poll",
				4: "Null (no data)",
				5: "CF-Ack (no data)",
				6: "CF-Poll (no data)",
				7: "CF-Ack+CF-Poll (no data)",
				8: "QoS Data",
				9: "QoS Data+CF-Ack",
				10: "QoS Data+CF-Poll",
				11: "QoS Data+CF-Ack+CF-Poll",
				12: "QoS Null (no data)",
				14: "QoS CF-Poll (no data)",
				15: "QoS CF-Ack+CF-Poll (no data)"
		},
		3: {  # Extension
				0: "DMG Beacon",
				1: "S1G Beacon"
		}
}

#Display modulations and frame types under test here
if clioptions.displaymods:
	print("Available modulations are...")
	print("\tALL (default)")
	for key, value in radiomodulation.items():
		print("\t" + key)
	print('\n Table of 802.11 Frame Types')
	print('{0:4s} - {1:7s}  {2:29s} {3}'.format('Type', 'Subtype', 'Name', 'Wireshark Display Filter'))
	for key, value in _dot11_subtypes.items():
		print (''.ljust(76, '-'))
		for subkey, subvalue in value.items():
			filter='0x{:03x}'.format(key) + f'{subkey:x}'
			print('{0:3d} {1:6d}      {2:29s} wlan.fc.type_subtype == {3}'.format(key, subkey, subvalue, filter))   	  
	exit()




print("Available modulations are...")
for key, value in radiomodulation.items():
	print(key, ' : ', value.show())

if clioptions.modrequested == 'ALL':  
	radiomodulationtouse = radiomodulation.copy()
else:
	radiomodulationtouse = {k: v for k, v in  radiomodulation.items() if k == clioptions.modrequested}
 
print("Selected modulation(s) are...")
for key, value in radiomodulationtouse.items():
	print(key, ' : ', value.show())





########################################################################
#	Funtions to create frames of various types
#
#	Type Management

def dot11_assocreq_0_0(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=0, # Assoc Request
			addr1=srcmac, 
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11AssoReq(cap='ESS+privacy', listen_interval=50)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_assocresp_0_1(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=1, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11AssoResp(cap='ESS+privacy', status=1, AID=1001)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_reassocreq_0_2(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=2, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11ReassoReq(cap='ESS+privacy', listen_interval=50, current_AP=srcmac)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_reassocresp_0_3(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=3, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11ReassoResp(cap='ESS+privacy', status=1, AID=1001)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_probereq_0_4(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=4, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11ProbeReq()
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_proberesp_0_5(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=5, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11ProbeResp(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 
	
#ToDo Layout Timing frame better
def dot11_timingadv_0_6(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=6, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_beacon_0_8(modSelected):
	"""dot11 Beacon type_subtype 0x08"""
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=8, # Management beacon frame
			addr1='ff:ff:ff:ff:ff:ff', # Broadcast address
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_atim_0_9(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=9, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 


def dot11_disassociation_0_10(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=10, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Disas(reason=4)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_authentication_0_11(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=11, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Auth(algo=0, seqnum=1, status=2)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

def dot11_deauthentication_0_12(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=12, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Deauth(reason=4)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the Action frames better
def dot11_action_0_13(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=13, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the Action frames better
def dot11_actionnoack_0_14(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=0, subtype=14, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 


############################################
#	Type Control


#ToDo: layout the frame better
def dot11_trigger_1_2(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=2, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_tack_1_3(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=3, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_beamreport_1_4(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=4, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_vhtndp_1_5(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=5, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_ctrlframeext_1_6(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=6, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_ctrlwrapper_1_7(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=7, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_blkackrqst_1_8(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=8, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_blkack_1_9(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=9, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_pspoll_1_10(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=10, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_rts_1_11(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=11, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 
	
#ToDo: layout the frame better
def dot11_cts_1_12(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=12, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_ack_1_13(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=13, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Ack()
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 

#ToDo: layout the frame better
def dot11_cfend_1_14(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=14, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 	
	

#ToDo: layout the frame better
def dot11_cfendack_1_15(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=1, subtype=15, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Beacon(cap='ESS+privacy')
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal)))	
	return  dot11frame 		


############################################
#	Type Data

#ToDo: layout the frame better
def dot11_data_2_0(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=0, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 		

#ToDo: layout the frame better
def dot11_datacfack_2_1(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=1, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))	
		/ LLC())
	return  dot11frame 		

#ToDo: layout the frame better
def dot11_datacfpoll_2_2(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=2, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 		

#ToDo: layout the frame better
def dot11_datacfackpoll_2_3(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=3, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 		

#ToDo: layout the frame better
def dot11_null_2_4(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=4, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	

#ToDo: layout the frame better
def dot11_cfack_2_5(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=5, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	

#ToDo: layout the frame better
def dot11_cfpoll_2_6(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=6, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	

#ToDo: layout the frame better
def dot11_cfackpoll_2_7(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=7, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	
	
#ToDo: layout the frame better
def dot11_qosdata_2_8(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=8, 
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	
	
def dot11_qosdatacfack_2_9(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=9,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 
	
def dot11_qosdatacfpoll_2_10(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=10,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 
	
def dot11_qosdatacfackpoll_2_11(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=11,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	
	
def dot11_qosnull_2_12(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=12,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 		

#No 2_13

def dot11_qoscfpoll_2_14(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=14,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 			

def dot11_qoscfackpoll_2_15(modSelected):
	vsielocal = bytearray(b'\x00\x01\x02\x03 ')
	vsielocal.extend(clioptions.iface.encode("utf-8"))
	vsieadder='_' + modSelected
	vsielocal.extend(vsieadder.encode("utf-8"))
	#print("Select: " + modSelected) 
	dot11frame = (radiomodulation.get(modSelected)
		/ Dot11(type=2, subtype=15,
			addr1=srcmac,
			addr2=srcmac,
			addr3=srcmac,
			ID=43210)
		/ Dot11Elt(ID='SSID', info=SSID, len=len(SSID))
		/ Dot11Elt(ID='Vendor Specific', len=len(vsielocal), info=(vsielocal))
		/ LLC())
	return  dot11frame 	
	

#Create frames for each modulation
for key, value in radiomodulationtouse.items():
	#Management
	packets.append(dot11_assocreq_0_0(key))
	packets.append(dot11_assocresp_0_1(key))
	packets.append(dot11_reassocreq_0_2(key))
	packets.append(dot11_reassocresp_0_3(key))
	packets.append(dot11_probereq_0_4(key))
	packets.append(dot11_proberesp_0_5(key))
	packets.append(dot11_timingadv_0_6(key))
		#No 0_7
	packets.append(dot11_beacon_0_8(key))
	packets.append(dot11_atim_0_9(key))
	packets.append(dot11_disassociation_0_10(key))
	packets.append(dot11_authentication_0_11(key))
	packets.append(dot11_deauthentication_0_12(key))
	packets.append(dot11_action_0_13(key))	
	packets.append(dot11_actionnoack_0_14(key))
	#Control
	packets.append(dot11_trigger_1_2(key))
	packets.append(dot11_tack_1_3(key))
	packets.append(dot11_beamreport_1_4(key))
	packets.append(dot11_vhtndp_1_5(key))
	packets.append(dot11_ctrlframeext_1_6(key))
	packets.append(dot11_ctrlwrapper_1_7(key))
	packets.append(dot11_blkackrqst_1_8(key))
	packets.append(dot11_blkack_1_9(key))
	packets.append(dot11_pspoll_1_10(key))
	packets.append(dot11_rts_1_11(key))
	packets.append(dot11_cts_1_12(key))
	packets.append(dot11_ack_1_13(key))
	packets.append(dot11_cfend_1_14(key))
	packets.append(dot11_cfendack_1_15(key))
	#Data
	packets.append(dot11_data_2_0(key))
	packets.append(dot11_datacfack_2_1(key))
	packets.append(dot11_datacfpoll_2_2(key))
	packets.append(dot11_datacfackpoll_2_3(key))
	packets.append(dot11_null_2_4(key))
	packets.append(dot11_cfack_2_5(key))
	packets.append(dot11_cfpoll_2_6(key))
	packets.append(dot11_cfackpoll_2_7(key))
	packets.append(dot11_qosdata_2_8(key))
	packets.append(dot11_qosdatacfack_2_9(key))
	packets.append(dot11_qosdatacfpoll_2_10(key))
	packets.append(dot11_qosdatacfackpoll_2_11(key))
	packets.append(dot11_qosnull_2_12(key))
		#No 2_13
	packets.append(dot11_qoscfpoll_2_14(key))
	packets.append(dot11_qoscfackpoll_2_15(key))


# #print('Building beacon frame with modulation \'abg\':')
# packets.append(dot11_beacon_0_8('abg'))

# #print('Building beacon frame with modulation \'HT\':')
# packets.append(dot11_beacon_0_8('HT'))

# #print('Building beacon frame with modulation \'HT40\':')
# packets.append(dot11_beacon_0_8('HT40'))

# #print('Building beacon frame with modulation \'HT3SS\':')
# packets.append(dot11_beacon_0_8('HT3SS'))

# #print('Building beacon frame with modulation \'HT3SS40\':')
# packets.append(dot11_beacon_0_8('HT3SS40'))

# #print('Building beacon frame with modulation \'VHT\':')
# packets.append(dot11_beacon_0_8('VHT'))

# #print('Building beacon frame with modulation \'HE\':')
# packets.append(dot11_beacon_0_8('HE'))


#for i in range(0, len(packets)):
#	print('Frame number: ' + str(i)) 
#	packets[i].show()   
 
for x in range(1):
	print('Injecting frame:')
	sendp(packets, iface=clioptions.iface, inter=0.05, return_packets=True)
