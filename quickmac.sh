#!/bin/bash

# first check if the user has macchanger installed
# if not, install it
if ! command -v macchanger &> /dev/null
then
    sudo apt install macchanger
fi


# initialize main loop
while true
do

#Define colors
 RED='\033[0;31m'
 GREEN='\033[0;32m'
 BLUE='\033[0;34m'
 RESET='\033[0m'

#Display choice and collect user input
 echo -e "${GREEN}---------------- ⊂(◉‿◉)つ ----------------${RESET}"
 echo -e "${GREEN}------------***QUICK CHANGE***------------${RESET}"
 echo -e "(${BLUE}1${RESET}) Apple"
 echo -e "(${BLUE}2${RESET}) Samsung"
 echo -e "(${BLUE}3${RESET}) CISCO"
 echo -e "(${BLUE}4${RESET}) Dell"
 echo -e "(${BLUE}5${RESET}) Nintendo"
 echo -e "(${BLUE}6${RESET}) IBM"
 echo -e "(${BLUE}7${RESET}) Huawei"
 echo -e "(${BLUE}8${RESET}) Microsoft"
 echo -e "(${BLUE}9${RESET}) Sony"
 echo -e "(${BLUE}10${RESET}) Murata"
 echo -e "${GREEN}-----------------------------------------${RESET}"
 echo -e "${BLUE}What type of device would you like to look like?${RESET}"
 echo -e "${GREEN}"
 read -ep "ENTER CHOICE: " choice
 read -ep "ENTER INTERFACE: " iface
 echo -e "${RESET}"


#Generate the last three octets of the mac address randomly
 rand=$(cat /dev/urandom | tr -dc 'A-F0-9' | fold -w 6 | head -n 1 | sed 's/./&:/2;s/./&:/5;')

#Create arrays for OUIs and select a random one per manufacturer
 apple=("f4:1b:a1:" "04:15:52:" "0c:30:21:" "10:1c:0c:" "24:a2:e1:")
 samsung=("08:37:3d:" "14:f4:2a:" "1c:62:b8:" "34:23:ba:" "50:01:bb:")
 cisco=("ec:c8:82:" "c8:d7:1:" "a8:b1:d4:" "d0:c2:82:" "c0:62:6b:")
 dell=("ec:f4:bb:" "18:03:73:" "84:8f:69:" "c8:1f:66:" "f8:db:88:")
 nintendo=("e8:4e:ce:" "78:a2:a0:" "58:bd:a3:" "d8:6b:f7:" "18:2a:7b:")
 ibm=("fc:cf:62:" "74:99:75:" "10:00:5a:" "34:40:b5:" "a8:97:dc:")
 huawei=("fc:48:ef:" "ec:23:3d:" "d0:7a:b5:" "ac:e2:15:" "78:d7:52:")
 microsoft=("dc:b4:c4:" "7c:1e:52:" "28:18:78:" "30:59:b7:" "7c:ed:8d:")
 sony=("fc:0f:e6:" "a0:e4:53:" "70:9e:29:" "40:2b:a1:" "b8:f9:34:")
 murata=("fc:c2:de:" "78:4b:87:" "5c:f8:a1:" "44:a7:cf:" "1c:99:4c:")

#Switch case for choices, assaign manufacturer based on choice.
 case $choice in
	1) choice="${apple}";;
	2) choice="${samsung}";;
	3) choice="${cisco}";;
	4) choice="${dell}";;
	5) choice="${nintendo}";;
	6) choice="${ibm}";;
	7) choice="${huawei}";;
	8) choice="${microsoft}";;
	9) choice="${sony}";;
	10) choice="${murata}";;
 esac
#Randomly select an OUI based on manufacturer and append the last three random octets.
 mac=${choice[ $RANDOM % ${#choice[@]} ]}$rand

#Bring the interface down
 echo -e "${BLUE}Taking interface down...${RESET}"
 sudo ifconfig $iface down

 #Change mac of interface via macchanger
 echo -e "${BLUE}Changing MAC...${RESET}"
 sudo macchanger -m $mac $iface

 #Now bring the interface back up
 echo -e "${BLUE}Bringing interface back up...${RESET}"
 sudo ifconfig $iface up

 echo -e "${GREEN}-------------------DONE!------------------${RESET}"
 

#Log mac address to maclog.txt
 now=$(date)
#Check if log file already exists
 if [ -a "maclog.txt" ] ;
 then
   echo "$iface changed to $mac on $now" >> maclog.txt
   echo "maclog.txt updated"
#If log file does not exsist, create it
 else
   echo "$iface changed to $mac on $now" > maclog.txt
   echo "maclog.txt created."
 fi

#Check if user has another interface
 echo -e "${GREEN}"
 read -ep "WOULD YOU LIKE TO CHANGE ANOTHER INTERFACE?(Y/N): " opt
 echo -e "${RESET}"
 if [[ $opt == "y" || $opt == "Y" ]];
 then
	continue
 else
	 break
 fi

done

echo -e "${GREEN}------------SEE YOU NEXT TIME!------------${RESET}"
