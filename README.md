# PacketCapture
Test various dot11 adapters in Linux for what they can and cannot receive

## Step 1
Can we inject 802.11 frames?  There are various types and many different modulations - what can we inject thta might be picked up?  Somewhat of a chicken and egg scenario - we want to evaluate what adapters might pick up off the air in monitor mode, but we have to use these to determine what adapters will actually transmit.  General rule: if at least one adapter can pick up some specific frame type at a given modulation, then we are pretty sure that injection works for those conditions.  

### Adapters under review for injection:
Bands: 2.4GHz / 5GHz / 6GHz adapters are represented; some only support specific bands, some WiFi4/5/6/6E, with varying channel width support (20/40/80/160MHz)

```
#### System1: Debian11 with updated firmware via git and custom 6.0 kernel on x64 platform
Ndx      Iface   Phy       Driver      Mode   Up?       Channel Width   Center    Packets Adapter
  0       mon0  phy0      iwlwifi   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       2817  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  1      wlan0  phy0      iwlwifi   managed     N                                       0  00.0 Network controller: Intel Corporation Device 2725 (rev 1a)
  2      wlan1  phy1    rtl88XXau   monitor     Y                                    2219  Senao EUB1200AC AC1200 DB [Realtek RTL8812AU]
  3      wlan2  phy2     carl9170   monitor     Y 149 (5745MHz) 40MHz 5755 MHz       1678  CACE Technologies Inc. AirPcap NX [Atheros AR9170+AR9104]
  4      wlan3  phy3      mt76x2u   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       1642  MediaTek Inc. MT7612U 802.11a/b/g/n/ac
  5      wlan4  phy4    ath9k_htc   monitor     Y  11 (2462MHz) 20MHz 2462 MHz       1459  Qualcomm Atheros Communications AR9271 802.11n
  6      wlan5  phy5    rtl88XXau   monitor     Y                                     990  Realtek Semiconductor Corp. RTL8814AU 802.11a/b/g/n/ac
  7      wlan6  phy6      mt7921u   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       1427  MediaTek Inc. Wireless_Device
  8      wlan7  phy7    rt2800usb   monitor     Y  11 (2462MHz) 20MHz 2462 MHz        408  Ralink Technology, Corp. RT5370
  9      wlan8  phy8    rt2800usb   monitor     Y  11 (2462MHz) 20MHz 2462 MHz        198  Ralink Technology, Corp. RT5372
 10      wlan9  phy9    rt2800usb   monitor     Y 149 (5745MHz) 40MHz 5755 MHz        256  NetGear, Inc. WNDA4100 802.11abgn 3x3:3 [Ralink RT3573]
 11     wlan10 phy10     carl9170   monitor     Y 149 (5745MHz) 40MHz 5755 MHz       1059  Qualcomm Atheros Communications AR9170 802.11n
```

#### System2: Kali Rolling with updated firmware via git and kernel 6.0.7-1kali1
```
Ndx      Iface   Phy       Driver      Mode   Up?       Channel Width   Center    Packets Adapter
  0       mon0  phy0      iwlwifi   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       8179  Intel Corporation Wireless 8265 / 8275 (rev 78)
  1      wlan0  phy0      iwlwifi   managed     N                                       0  Intel Corporation Wireless 8265 / 8275 (rev 78)
  2      wlan1  phy1   ath10k_pci   monitor     Y 149 (5745MHz) 80MHz 5775 MHz       8590  Qualcomm Atheros QCA986x/988x 802.11ac Wireless Network Adapter
  3      wlan2  phy2        ath9k   monitor     Y 149 (5745MHz) 40MHz 5755 MHz       8270  Qualcomm Atheros AR928X Wireless Network Adapter (PCI-Express) (rev 01)
```

```
### Table of 802.11 Frame Types under test
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

