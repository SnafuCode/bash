#!/usr/bin/env bash
##################################################
# This script is used for parsing pcap files by  #
# extracting associated EAPOL and Beacon packets #
# using Tshark and Bash. This makes it easy to   #
# quickly sort out the frames needed for         #      
# password cracking or for furth analysis        #
# This script is designed to work with standard  #
# WPA2 EAPOL handshake but could be modified to  #
# suit other needs. After parsing the pcap file  #
# it will also pompt the user to run a dictonary #
# attack using Hashcat.                          #
#------------------------------------------------#
#     2024 Erin Hall - snafucode@proton.me       #
##################################################

# Get pcap file
while true
do
	read -ep "Enter path to pcap file: " pcap_input
	if [[ -s $pcap_input || -n $pcap_input && -f $pcap_input ]]
	then
		echo "File accepted"
		while true
		do
			read -ep "Would you like to generate a report?(Y/N): " report
			choice="${report^^}"
			if [[ $choice = "Y" || ${choice} = "N" ]]
			then
				break							
			else
				echo "No a valid choice"
				continue
			fi
		done
		break
	else
		echo "File does not exist!"
		continue
	fi
done

msg="W o r k i n g . . .  "
printf '\n------------------------------------------------\n'
for i in $msg;
do
	printf '%s' $i
	sleep 0.1
done
printf '\n------------------------------------------------\n'

# Decalre indexed arrays
declare -a frame1_macs
declare -a frame2_macs
declare -a frame3_macs
declare -a beacon_seqs
declare -a macs
declare -a bssid_macs
declare -a output_files
declare -a passwords

# Declare associative array
declare -A client_macs

# Declare variables
frame1_total=0
frame2_total=0
frame3_total=0
bssid_total=0
report_date=$(date "+%F%T")
file_date=$(date "+%F_%S")

# Find the da mac of each eapol frame 2 to obtine the BSSID of each AP
bssid=$(tshark -r ${pcap_input} -T fields -e wlan.da -Y "wlan_rsna_eapol.keydes.msgnr==2" | sort | uniq)
# Populate array
for mac in $bssid;
do
	bssid_macs+=($mac)
	bssid_total=$[ $bssid_total + 1 ]	
done

# Find client devices of each AP that had an eapol frame 2 - use an associative array here to have key-value pairs
count=0
for mac in ${bssid_macs[@]};
do
	client=$(tshark -r ${pcap_input} -T fields -e wlan.da -Y "wlan.fc.type_subtype == 11 && wlan.ta==$mac" | sort | uniq)
	client_macs[$count]="${client}"
	count=$[$count + 1]
done

# Eapol frame 2 is essential for a successful handshake. If frame 2 isn't present,
# don't waste time checking  for a frame 1 or 3
frame2=$(tshark -r ${pcap_input} -T fields -e wlan.ta -Y "wlan_rsna_eapol.keydes.msgnr==2" | sort | uniq)
# Populate array
for frame in $frame2;
do
	frame2_macs+=($frame)
	frame2_total=$[ $frame2_total + 1 ]
done

if [ ${frame2_total} -gt 0 ]
then
	printf '\nFound frame 2 eapol packet\n'
	printf 'MAC: %s\n' "$frame2"
	echo "-----------------------------------------"
	echo ""
else
	printf 'No frame 2 eapol packet\n'
	printf 'Exiting\n'
	echo "-----------------------------------------"
	echo""	
	exit
fi

# Find all eapol frame 1 packets 
frame1=$(tshark -r ${pcap_input} -T fields -e wlan.da -Y "wlan_rsna_eapol.keydes.msgnr==1" | sort | uniq)
# Populate array
for frame in $frame1;
do
	frame1_macs+=($frame)
	frame1_total=$[ $frame1_total + 1 ]
done
	
if [ ${frame1_total} -gt 0 ]
then
	printf 'Found a matching frame 1 eapol packet\n'
	printf 'MAC: %s\t\n' "$frame1"
	echo "-----------------------------------------"
	echo""
else
	printf 'No frame 1 eapol packet\n'
	printf 'Checking for frame 3\n'
	echo "-----------------------------------------"
	echo""
fi

# Find all eapol frame 3 packets - filter for the destination mac
frame3=$(tshark -r ${pcap_input} -T fields -e wlan.da -Y "wlan_rsna_eapol.keydes.msgnr==3" | sort | uniq)
# Populate array
for frame in $frame3;
do
	frame3_macs+=($frame)
	frame3_total=$[ $frame3_total + 1 ]
done

# Check for eapol frame 3. If frames 1 and 3 are both missing, exit program
if [ ${frame3_total} -gt 0 ]
then
	printf 'Found a matching frame 3 eapol packet\n'
	printf 'MAC: %s\t\n' "$frame3"
	echo "-----------------------------------------"
	echo""
elif [[ ${#frame3_macs[*]} -lt 1 && ${#frame1_macs[*]} -lt 1 ]]
	then
		printf 'Frames 1 and 3 are missing!\n'
		printf 'Exiting...\n'
		echo "-----------------------------------------"
		echo""
		exit
fi

# A beacon frame from the associated AP is necessary along with the the eapol packets
for (( i=0; i<$bssid_total; i++ ))
	do
# Grab the seqno for the first beacon frame so we can export only 1 beacon packet per file
	beacon_seq=$(tshark -r ${pcap_input} -T fields -e frame.number -Y "wlan.addr==${bssid_macs[$i]} && wlan.fc.type_subtype==0x0008" | head -1)
  beacon_seqs+=($beacon_seq)
done

if [ ${#beacon_seqs[*]} -gt 0 ]
then
	printf 'Found a beacon frame\n'
	printf 'Frame number: %d\n' ${beacon_seqs}
	echo "-----------------------------------------"
	echo""
else
	printf 'No beacon frames found!\n'
	printf 'Exiting...\n'
	exit	
fi

# Print out all the unique SSIDs 
echo "Unique SSIDs:"
for (( i=0; i<$bssid_total; i++ ))
do
	ssid=$(tshark -r ${pcap_input} -T fields -e wlan.ssid -Y "(wlan.fc.type_subtype==0x0008&&wlan.addr==${bssid_macs[$i]})" | sort | uniq | xxd -r -p)
    ssid_list+=("$ssid")
done
printf '%s\n' "${ssid_list[@]}"

for (( i=0; i<$bssid_total; i++ ))
do
	# Array to hold the name of output files, this will be used for exporting the pcaps and for Hashcat
	# Use quotations for SSIDs that contain spaces
	output_files+=("${ssid_list[$i]}_handshake_${file_date}_${i}".pcap)

	tshark -r ${pcap_input} -Y "(wlan.addr==${bssid_macs[$i]} && wlan.fc.type_subtype==0x0008 && frame.number==${beacon_seqs[$i]}) || (eapol && wlan.addr==${frame2_macs[$i]} || wlan.addr==${frame1_macs[$i]})" -w "${output_files[$i]}" # Keep quotations for SSIDs that contain spaces

done

# Now check is the user wants to try and crack to passwords with a dictionary attack
while true
do
	read -ep "Would you like to run a dictionary attack using Hashcat?(Y/N) " hc_choice
	user_choice="${hc_choice^^}"
		if [[ $user_choice = "Y" || $user_choice = "N" ]]
		then
			if [[ $user_choice = "Y" ]]		
			then
				read -ep "Enter path to wordlist: " wordlist
				if [[ -f $wordlist ]]				
				then					
					# Generate a Hashcat usable file
					echo -e	"  /\_/\  "
					echo -e " ( o.o ) "
					echo -e	"  > ^ <  "
					echo "==================== Cat Stuff ===================="
					sleep 3
					for (( i=0; i<$bssid_total; i++ ))
					do
						sudo hcxpcapngtool  -o "${ssid_list[$i]}".22000 "${output_files[$i]}"
						# Crack password using Hashcat
						hashcat -m 22000 -a 0 "${ssid_list[$i]}".22000 "${wordlist}" --outfile-format 2 -o password.txt 
						cracked=$(cat password.txt | tail -1)
						passwords+=("$cracked")
						echo ${#passwords[@]}
					done
					break
				else
					echo "Not a valid file! Try again."
					break
				fi
			 else
				break
			fi	
		else
			echo "No a valid choice"
			continue
		fi
done
if [[ ! -f passwords.txt ]]
then
	touch passwords.txt
fi

# Generate report if user selected yes
if [ $choice = "Y" ]
then
	function build_report {
		# Get channels for each AP
		declare -a channels
		for (( i=0; i<$bssid_total; i++ ))
  	do
 			channel=$(tshark -r $pcap_input -T fields -e "wlan.ds.current_channel" -Y "wlan.ta==${bssid_macs[i]}" | sort | uniq)
    	channels+=($channel)
  	done
		# Check for connected devices
		declare -a devices
		for ap in $bssid_macs;
			do
				ap=$(tshark -r ${pcap_input} -T fields -e wlan.da -Y "wlan.fc.type_subtype==11 && wlan.ta==$ap" | sort | uniq)
				devices+=($ap)
			done
			printf "==================== REPORT ====================\n"
			printf "GENERATED ON: %s\n\n" "$report_date"
			for (( i=0; i<$bssid_total; i++))
			do
				printf "SSID: %s\n" "${ssid_list[$i]}"
				printf "PASSWORD: %s\n" "${passwords[$i]}"
				printf "CHANNEL: %s\n" "${channels[$i]}"
				printf "BSSID: %s\n" "${bssid_macs[$i]}"
				printf "CLIENT: %s\n" "${client_macs[$i]}"
				printf "\n\n"
			done
			printf "================== ***NOTES*** ==================\n"
			printf "Duplicate SSIDs are likey seperate APs on the same network(check the BSSID).\nClients are found by checking for the authentications frame.\nFor a more accurate number of clients, search for data frames in within your pcap.\n"
		}	
	
	build_report >> "wifi_report_${report_date}.txt"

	exit

	echo "Report generated"
else
	echo "No report"
fi	

echo ""
echo "------------------------------------------------"
echo "Complete"
echo "------------------------------------------------"
exit
