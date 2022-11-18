# PacketCapture

##Test various dot11 adapters in Linux for what they can and cannot receive

###Step 1
Can we inject 802.11 frames?  There are various types and many different modulations - what can we inject thta might be picked up?  Somewhat of a chicken and egg scenario - we want to evaluate what adapters might pick up off the air in monitor mode, but we have to use these to determine what adapters will actually transmit.  General rule: if at least one adapter can pick up some specific frame type at a given modulation, then we are pretty sure that injection works for those conditions.  

Adapters under review for injection:
Bands: 2.4GHz / 5GHz / 6GHz adapters are represented; some only support specific bands, some WiFi4/5/6/6E, with varying channel width support (20/40/80/160MHz)

```
System1: Debian11 with updated firmware via git and custom 6.0 kernel on x64 platform
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

System2: Kali Rolling with updated firmware via git and 

