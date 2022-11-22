#!/bin/bash +x

file=$1

type_subtype=(	0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e \
				0x12 0x13 0x14 0x15 0x16 0x17 0x18 0x19 0x1a 0x1b 0x1c 0x1d 0x1e 0x1f \
				0x20 0x21 0x22 0x23 0x24 0x25 0x26 0x27 0x28 0x29 0x2a 0x2b 0x2c 0x2e 0x2f
			 )
#type_subtype=( 0x04 )

numframesintrace=$(capinfos ${file} | grep -e "Number of packets:")

printf "Frame counts per Type/Subtype and capture device [System3]\n"
printf "File: [${file}] with Total ${numframesintrace}\n" 
printf "Type/Subtype %22s      %s     %s    %s    %s    %s    %s    %s\n" "File" "Total" "mon0" "wlan1" "wlan2" "wlan3" "wlan4" 

for type in ${type_subtype[@]}; 
do
framects=$(editcap -S 0 ${file} - | tshark -r - -Y "wlan.addr == 01:23:45:67:89:ab and wlan.fc.type_subtype == ${type}" -w - | \
tshark -r - -q -z io,stat,0,FRAMES,\
"FRAMES()frame.interface_name == mon0",\
"FRAMES()frame.interface_name == "wlan1"",\
"FRAMES()frame.interface_name == "wlan2"",\
"FRAMES()frame.interface_name == "wlan3"",\
"FRAMES()frame.interface_name == "wlan4"" | grep "<>" | cut -d '|' -f 3,4,5,6,7,8)
printf " [%8s]  ${file} | ${framects}\n" "${type}"
done
echo


#for file in $(ls DS1/); do echo $file; ./pcapfilter.sh DS1/${file};  done | tee DS1_5GHz_abg_2.txt
#for file in $(ls DS2/); do echo $file; ./pcapfilter.sh DS2/${file};  done | tee DS2_24GHz_abg_2.txt

#cat DS1_5GHz_abg_2.txt | grep '^ \[' > ds1.txt
#cat DS2_24GHz_abg_2.txt | grep '^ \[' > ds2.txt
