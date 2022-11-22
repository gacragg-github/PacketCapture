# 802.11 Packet Capture and Injection
Test various dot11 adapters in Linux for what they can and cannot receive

## Step 1
Can we inject 802.11 frames?  There are various types of frames and many different modulations - what can we inject thta might be picked up?  Somewhat of a chicken and egg scenario - we want to evaluate what adapters might pick up off the air in monitor mode, but we have to use these to determine what adapters will actually transmit.  General rule: if at least one adapter can pick up some specific frame type at a given modulation, then we are pretty sure that injection works for those conditions.  

### Adapters under review for injection:
Bands: 2.4GHz / 5GHz / 6GHz adapters are represented; some only support specific bands, some WiFi4/5/6/6E, with varying channel width support (20/40/80/160MHz).  Some are USB, some miniPCIe, and some M.2.  Still others, not shown, do not support monitor mode so can neither inject nor capture 802.11 traffic.

```
System1: Debian11 with updated firmware via git and kernel 6.0.0-0.deb11.2-amd64 on x64 [injection]
Ndx      Iface   Phy       Driver      Mode   Up?       Channel Width   Center    Packets Adapter
  0       mon0  phy0      iwlwifi   monitor     Y 149 (5745MHz) 80MHz 5775 MHz    7303591  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  1      wlan0  phy0      iwlwifi   managed     N                                       0  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  2      wlan1  phy1    rtl88XXau   monitor     Y                                 7363565  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
  3      wlan2  phy2     carl9170   monitor     Y 149 (5745MHz) 40MHz 5755 MHz    5967777  CACE Technologies Inc. AirPcap NX [Atheros AR9170+AR9104]
  4      wlan3  phy3    rtl88XXau   monitor     Y                                 5783179  Realtek Semiconductor Corp. RTL8814AU 802.11a/b/g/n/ac
  5      wlan4  phy4      mt76x2u   monitor     Y 149 (5745MHz) 80MHz 5775 MHz    7232867  MediaTek Inc. MT7612U 802.11a/b/g/n/ac
  6      wlan5  phy5      mt7921u   monitor     Y 149 (5745MHz) 80MHz 5775 MHz    7474026  MediaTek Inc. Wireless_Device
  7      wlan6  phy6    ath9k_htc   monitor     Y   6 (2437MHz) 20MHz 2437 MHz    7331242  Qualcomm Atheros Communications AR9271 802.11n
  8      wlan7  phy7    rt2800usb   monitor     Y   6 (2437MHz) 20MHz 2437 MHz    7236935  Ralink Technology, Corp. RT5370
  9      wlan8  phy8    rt2800usb   monitor     Y   6 (2437MHz) 20MHz 2437 MHz    5908307  Ralink Technology, Corp. RT5372
 10      wlan9  phy9    rt2800usb   monitor     Y 149 (5745MHz) 40MHz 5755 MHz    7312658  NetGear, Inc. WNDA4100 802.11abgn 3x3:3 [Ralink RT3573]
 11     wlan10 phy10     carl9170   monitor     Y 149 (5745MHz) 40MHz 5755 MHz         95  Qualcomm Atheros Communications AR9170 802.11n
```
Notes: The RTL chipsets use the [Aircrack-ng driver](https://github.com/aircrack-ng/rtl8812au) 5.6.4.2 and don't show the channel information when set to 5GHz.

```
System2: Kali Rolling with updated firmware via git and kernel 6.0.0-kali3-amd64 on x64 [injection]
Ndx      Iface   Phy       Driver      Mode   Up?       Channel Width   Center    Packets Adapter
  0       mon0  phy0      iwlwifi   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       8179  Intel Corporation Wireless 8265 / 8275 (rev 78)
  1      wlan0  phy0      iwlwifi   managed     N                                       0  Intel Corporation Wireless 8265 / 8275 (rev 78)
  2      wlan1  phy1   ath10k_pci   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       8590  Qualcomm Atheros QCA986x/988x 802.11ac Wireless Network Adapter
  3      wlan2  phy2        ath9k   monitor     Y 149 (5745MHz) 40MHz 5755 MHz       8270  Qualcomm Atheros AR928X Wireless Network Adapter (PCI-Express) (rev 01)
```

Capture adapters used to evaluate injection:
```
System3: Debian11 with updated firmware via git and kernel 6.0.0-0.deb11.2-amd64 on x64 [capture]
Ndx           Iface   Phy       Driver      Mode   Up?       Channel Width    Packets Adapter
  0            mon0  phy0      iwlwifi   monitor     Y 149 (5745MHz) 80MHz       1794  Intel Corporation Wi-Fi 6 AX210/AX211/AX411 160MHz (rev 1a)
  1           wlan0  phy0      iwlwifi   managed     N                              0  Intel Corporation Wi-Fi 6 AX210/AX211/AX411 160MHz (rev 1a)
  2           wlan1  phy1      mt7921u   monitor     Y 149 (5745MHz) 80MHz       1483  MediaTek Inc. Wireless_Device
  3           wlan2  phy2      mt76x2u   monitor     Y 149 (5745MHz) 80MHz       1555  MediaTek Inc. MT7612U 802.11a/b/g/n/ac
  4           wlan3  phy3    rtl88XXau   monitor     Y                           1119  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
  5           wlan4  phy4    rtl88XXau   monitor     Y                            793  Realtek Semiconductor Corp. RTL8814AU 802.11a/b/g/n/ac
```


```
Table of 802.11 Frame Types under test
Types
  Manangement: 0
  Control:     1
  Data:        2

Type - Subtype  Name                          Wireshark Display Filter
----------------------------------------------------------------------------
  0      0      Association Request           wlan.fc.type_subtype == 0x0000
  0      1      Association Response          wlan.fc.type_subtype == 0x0001
  0      2      Reassociation Request         wlan.fc.type_subtype == 0x0002
  0      3      Reassociation Response        wlan.fc.type_subtype == 0x0003
  0      4      Probe Request                 wlan.fc.type_subtype == 0x0004
  0      5      Probe Response                wlan.fc.type_subtype == 0x0005
  0      6      Timing Advertisement          wlan.fc.type_subtype == 0x0006
  0      8      Beacon                        wlan.fc.type_subtype == 0x0008
  0      9      ATIM                          wlan.fc.type_subtype == 0x0009
  0     10      Disassociation                wlan.fc.type_subtype == 0x000a
  0     11      Authentication                wlan.fc.type_subtype == 0x000b
  0     12      Deauthentication              wlan.fc.type_subtype == 0x000c
  0     13      Action                        wlan.fc.type_subtype == 0x000d
  0     14      Action No Ack                 wlan.fc.type_subtype == 0x000e
----------------------------------------------------------------------------
  1      2      Trigger                       wlan.fc.type_subtype == 0x0012
  1      3      TACK                          wlan.fc.type_subtype == 0x0013
  1      4      Beamforming Report Poll       wlan.fc.type_subtype == 0x0014
  1      5      VHT/HE NDP Announcement       wlan.fc.type_subtype == 0x0015
  1      6      Control Frame Extension       wlan.fc.type_subtype == 0x0016
  1      7      Control Wrapper               wlan.fc.type_subtype == 0x0017
  1      8      Block Ack Request             wlan.fc.type_subtype == 0x0018
  1      9      Block Ack                     wlan.fc.type_subtype == 0x0019
  1     10      PS-Poll                       wlan.fc.type_subtype == 0x001a
  1     11      RTS                           wlan.fc.type_subtype == 0x001b
  1     12      CTS                           wlan.fc.type_subtype == 0x001c
  1     13      Ack                           wlan.fc.type_subtype == 0x001d
  1     14      CF-End                        wlan.fc.type_subtype == 0x001e
  1     15      CF-End+CF-Ack                 wlan.fc.type_subtype == 0x001f
----------------------------------------------------------------------------
  2      0      Data                          wlan.fc.type_subtype == 0x0020
  2      1      Data+CF-Ack                   wlan.fc.type_subtype == 0x0021
  2      2      Data+CF-Poll                  wlan.fc.type_subtype == 0x0022
  2      3      Data+CF-Ack+CF-Poll           wlan.fc.type_subtype == 0x0023
  2      4      Null (no data)                wlan.fc.type_subtype == 0x0024
  2      5      CF-Ack (no data)              wlan.fc.type_subtype == 0x0025
  2      6      CF-Poll (no data)             wlan.fc.type_subtype == 0x0026
  2      7      CF-Ack+CF-Poll (no data)      wlan.fc.type_subtype == 0x0027
  2      8      QoS Data                      wlan.fc.type_subtype == 0x0028
  2      9      QoS Data+CF-Ack               wlan.fc.type_subtype == 0x0029
  2     10      QoS Data+CF-Poll              wlan.fc.type_subtype == 0x002a
  2     11      QoS Data+CF-Ack+CF-Poll       wlan.fc.type_subtype == 0x002b
  2     12      QoS Null (no data)            wlan.fc.type_subtype == 0x002c
  2     14      QoS CF-Poll (no data)         wlan.fc.type_subtype == 0x002e
  2     15      QoS CF-Ack+CF-Poll (no data)  wlan.fc.type_subtype == 0x002f
----------------------------------------------------------------------------
```

How to know what devices can inject properly?  This is where we need reliable capture but we don't know if we have that.  THe approach then is just try to inject and capture with multiple adapters and see what is/is not shown.  If we see the expected frame from at least on capture adapter, then we have confidence that the adapter can inject that frame type.  Same with modulation, but not all adapters pass up correct modulation information in all cases so will have to look and compare.

Some of the files used for this work:
```
File                Description                                                                         Example
interfaces.sh       Displays state information about wireless interfaces on Linux device                sudo ./interfaces.sh
wifisetup.sh        Configure adapters for monitor mode                                                 sudo ./wifisetup -c '149 80MHz'
CaptureTestVx.py    Use scapy to inject dot11 frames                                                    sudo ./CaptureTestV0.2.py -m abg -i wlan1
sysdetails.sh       Collect some details about host systems                                             sudo ./sysdetails.sh > source.txt 2>&1
pcapfilter.sh       Rollup per interface / per type-subtype frames counts                               ./pcapfilter.sh <pcap file>
```

First pass through, inject only abg modulated frames; so for 5GHz, 802.11a, and for 2.4GHz, 802.11g.  Both with rate set to 24Mbps.
Setup is then to capture on System3 (all interfaces at the same time) and run an injection test through, for example, System1_mon0 interface.  Injected frames are 'tagged':
```
All frames use this MAC address:
    wlan.addr == 01:23:45:67:89:ab
SSID in use is the injection interface (for frames that have an SSID field; example: wlan1):
    wlan.ssid == "wlan1"
Frames have a data trailer which includes injection interface and Tx modulation attempted:
    Tag: Vendor Specific: 3Com
    Tag Number: Vendor Specific (221)
    Tag length: 14
    OUI: 00:01:02 (3Com)
    Vendor Specific OUI Type: 3
    Vendor Specific Data: 03206d6f6e31315f616267 [hex to UTF8 shows mon11_abg]
```
To fight against in-the-air packet loss, run the injection routine mutliple times; for example,

```
for i in {0..4}; do sudo ./CaptureTestV0.2.py -m abg -i xxxx; sleep 1; done
```

Datasets:
```
DS1: inject all types on each injection interface, one interface at a time, and see if any adapters are able to inject all frame types at a modulations for 5GHz.
DS2: inject all types on each injection interface, one interface at a time, and see if any adapters are able to inject all frame types at g modulations for 2.4GHz.
```
See Analysis_DS1_DS2_abg.md for analysis of DS1/DS2 datasets.  Conclude: we have four adapters that have reasonable injection capability:
```
Interface   Adapter     
sys1_wlan1  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
sys1_wlan3  Realtek Semiconductor Corp. RTL8814AU 802.11a/b/g/n/ac 
sys1_wlan4  MediaTek Inc. MT7612U 802.11a/b/g/n/ac
sys1_wlan9  NetGear, Inc. WNDA4100 802.11abgn 3x3:3 [Ralink RT3573]
```

## Step 2: How do these adapters handle various modulations?
