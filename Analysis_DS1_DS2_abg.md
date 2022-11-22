# Analysis of datasets DS1 and DS2

Injection routine is executed 5x times on both 2.4 and 5GHz bands, for a total of 10 runs per injection interface.  So for a given capture interface, it should see from 0 to 10 of each frame type.  We might see zero if the frame is not actually injected, or if the capture adapter cannot pick up this type of frame at the given modulation.  We might see less than 10 but more than zero if there is some packet loss in the RF environment.  Adding up all the visible frames by capture interface and type (note these are all from System3, the capture system):

![DS1_2](https://user-images.githubusercontent.com/70328008/203403931-34a4e74c-06a1-4b2b-a796-9421398ebc13.png)

This is a stacked bar chart of the sum of each frame type, captured by the interfaces on System3.  Some anomalies are called out here:

0. sys3_wlan4 crashed midway through this testing and the device seemed to miss a lot of traffic anyway.  In general, will ignore this capture adapter due to the issues observed.
1. Frame type 0x00 (Association Request) shows more than the total injected frames possible.  This is an artifact from testing: type 0x17 (Control Wrapper) contains an Association Request frame so with Wireshark filtering, both of these type/subtype show so are counted multiple times.  They could be excluded, but the point is to see what traffic is injected and captured, so the answer is apparent so no need to further process.
2. Frame type 0x20 (Data) has more frames collected than injected.  In this case, it is due to certain adapters transmitting extranous frames of this type.  Namely, sys1_mon0 send extra Data and CTS (0x12) frames.
3. No 0x16 type traffic (Control Frame Extension) was present in any capture.  Conclude that it is not sent by any adapter tested.  ToDo: it is possible to capture on the monitor interface used for injection; this is not typically recommended because there is no guarantee that the frame gets transmitted so presence here does not have a usable RadioTap (or PPI) header nor any type of confirmation of actual transmission.  However, to investigate, would be interesting to see if this is actually sent to the driver or not to see where it might be dropped.
4. sys3_mon0 interface never picked up 0x13 frames (TACK) though other adapters did.  Is there something with this driver that prevents this frame type from being captured?
5. Same as (4) but for 0x17 frames (Control Wrapper).
6. sys3_wlan2 is not able to pickup 0x1b (RTS) frames.

As for injection, we are looking for a reliable adapter that provides for an injection capability of all (or as many as possible) frame types at the configured modulation.  In this study, we are then looking for frames that were transmitted at 24Mbps on both 2.4 and 5GHz.  This leaves us with the following adapters, ignoring frame type 0x16 as no interface seems to be able to inject this specific type:

```
Adapter         Verdict         Reason
sys1_mon0       No              Crashes; only some frames injected; only use 1Mbps
sys1_wlan1      Yes             Uses 24Mbps
sys1_wlan2      No              No frames injected on 5GHz (regulatory issue?)
sys1_wlan3      Yes             Uses 24Mbps
sys1_wlan4      Yes             Uses 24Mbps
sys1_wlan5      No              All frames types but only 6Mbps (5GHz) or 1Mbps (2.4GHz)
sys1_wlan6      No              No frames injected on either band
sys1_wlan7      No              No frames injected on 5GHz (2.4GHz only)
sys1_wlan8      No              No frames injected on 5GHz (2.4GHz only)
sys1_wlan9      Yes             Uses 24Mbps
sys1_wlan10     No              No frames injected on 5GHz (regulatory issue?)
sys2_mon0       No              Cannot inject frame type 0x18
sys2_wlan1      No              No frames injected on 5GHz
sys2_wlan2      No              No frames injected on 5GHz; partial on 2.4GHz
```

Notes: Some of these might be OK for use if only need 2.4GHz.  Somewhat arbitrarily, I am looking for something that is the most flexible.  Results might change, too, when different modulations are used (e.g. HT, VHT, HE, etc).  To do: evaluate 6GHz with WiFi6E.
