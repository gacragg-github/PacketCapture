#Analysis of datasets DS1 and DS2

Injection routine is executed 5x times on both 2.4 and 5GHz bands, for a total of 10 runs per injection interface.  So for a given capture interface, it should see from 0 to 10 of each frame type.  We might see zero if the frame is not actually injected, or if the capture adapter cannot pick up this type of frame at the given modulation.  We might see less than 10 but more than zero if there is some packet loss in the RF environment.  Adding up al the visible frames by capture interfae and type:

