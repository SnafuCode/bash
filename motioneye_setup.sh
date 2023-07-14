#!/bin/bash

###################################################################
# This script installs and configures motioneye on a raspberry pi #
# from the new dev  branch of motioneye.                          #
# see https://github.com/motioneye-project/motioneye/tree/dev     #
# for details of this project.                                    #
###################################################################

# define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RESET='\033[0m'

# display welcome message
echo "======================================="
echo -e "========== ${GREEN}MOTIONEYE INSTALL${RESET} =========="
echo "======================================="

# define choice variable and start while loop
choice=0
while true
do
	# prompt user for camera model
	echo -e "Please choose camera version"
	echo -e "(${BLUE}1${RESET}) Camera Module v2"
	echo -e "(${BLUE}2${RESET}) Camera Module v3"
	read -ep "Enter Choice: " choice

	if [[ $choice = 1 ]] || [[ $choice = 2 ]] ; 
	then
		break
	else
		echo ""
		echo -e "${RED}Not a valid choice! Please choose either 1 or 2...${RESET}"
		continue
	fi
done

# update the repos before install
echo -e "${BLUE}Updating repo...${RESET}"
sudo apt update
sleep 1
echo -e "${GREEN}Done${RESET}"
echo ""

# check if user is using camera v3
# libcamera-tools is required for the v3 camera module 3
if [[ $choice -eq 2 ]] ;
 then
  echo -e "${BLUE}Installing libcamera-tools...${RESET}"
  sudo apt install libcamera-tools -y
fi

# check if user is using camera v2
# if using camera module v2, you must enable Legacy camera and IC2 options
if [[ $choice -eq 1 ]] ;
 then
	echo -e "${BLUE}Now enabling IC2 and Legacy Camera options...${RESET}"
 	sleep 1
	sudo raspi-config nonint do_i2c 0
	echo ""
	sudo raspi-config nonint do_legacy 0
fi


# install python3 and dependencies for the new branch of motioneye
echo -e "${BLUE}Install python3 and dependencies...${RESET}"
sleep 1
sudo apt --no-install-recommends install ca-certificates curl python3 python3-distutils
echo ""
echo -e "${BLUE}Install and configure pip...${RESET}"
curl -sSfO 'https://bootstrap.pypa.io/get-pip.py'
echo -e "${BLUE}Please wait...${RESET}"
sleep 1
curl -sSfO 'https://bootstrap.pypa.io/get-pip.py'
sudo python3 get-pip.py
rm get-pip.py
echo ""
echo -e "${BLUE}configuring pip...${RESET}"
printf '%b' '[global]\nextra-index-url=https://www.piwheels.org/simple/\n' | sudo tee /etc/pip.conf > /dev/null
echo ""
sleep 1
echo -e "${BLUE}Installing Motioneye...${RESET}"
sleep 1
sudo python3 -m pip install 'https://github.com/motioneye-project/motioneye/archive/dev.tar.gz'
sudo motioneye_init
echo ""
sleep 2
echo -e "${GREEN}All done!${RESET}"
echo ""
echo "================================"
echo -e "${BLUE}Disabling Motion and restarting Motioneye...${RESET}"
sleep 1
sudo systemctl disable --now motion
sleep 1
sudo systemctl restart motioneye

# work around for camera module 3 - make a motion.sh file in the users home directory, and then point motioneye.conf to it. 
# next edit /boot/config.txt to use the imx708(camera module v3) dtoverlay
if [[ $choice -eq 2 ]] ;
then
	echo -e '#!/bin/bash\n/usr/bin/libcamerify /usr/bin/motion $@' >> /home/$USER/motion.sh
	sudo chmod +x /home/$USER/motion.sh

	sleep 1
	sudo sed -i "s|#motion_binary /usr/bin/motion|motion_binary /home/$USER/motion.sh|" /etc/motioneye/motioneye.conf
	sleep 2
	sudo sed -i 's|#start_x=1|dtoverlay=imx708|' /boot/config.txt
	sudo sed -i 's|camera_auto_detect=1|dtoverlay=imx708|' /boot/config.txt
fi

# load the bcm2835-v4l2 moduel using modprobe
echo -e "${BLUE}modprobe bcm2835-v4l2...${RESET}"
sleep 1
sudo modprobe bcm2835-v4l2
echo ""
echo -e "============== ${GREEN}ALL DONE!${RESET} ============="
echo -e "\e[1;31mYOU MUST REBOOT NOW. AFTER REBOOT CONNECT TO YOUR LOCAL IP ON PORT 8765 TO USE MOTIONEYE\e[0m"

