#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

#Start tests-----------------------------------
echo "Starting Ansible automation testing"

#Check if ansile is installed
ansible_status=$(dpkg -s ansible)>/dev/null
if [[ $ansible_status == *"Status: install ok installed"* ]]; then
	echo -e "$GREEN Ansible installed $NC"
else
	echo -e "$RED Ansible not installed $NC"
	exit 2
fi

#Install_apt_package.yml
#Check the package is not install
echo "Testing Install_apt_package.yml playbook..."
echo "Please enter the name of the package you'd like to test, make sure it isn't installed already."
echo "Note that during the automation testing it will be removed again."
read package_name

package_status=$(dpkg -s $package_name) >/dev/null

#if package is already installed abort the test
if [[ $package_status == *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is already installed $NC"
	echo "Install_apt_package.yml test aborting..."
#else install package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/testing_playbook/install_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=master package=$package_name"
	#Check the package if installed
	package_status=$(dpkg -s $package_name) >/dev/null
	if [[ $package_status == *"Status: install ok installed"* ]]; then
		echo -e "$GREEN $package_name is now installed $NC"
	else
		echo -e "$RED $package_name not installed $NC"
		exit 3
	fi
fi


#Remove_apt_package.yml
#Check the package is installed
#Run playbook
#Check the package if removed

#Kickstart_computer_node.yml
#Run playbook in a “pure johnny”
#Run testing johnny script

#Kickstart_control_node.yml
#Run playbook in a “pure lisa”
#Run testing lisa script

#Reboot.yml
#Record current time (T1)
#Run playbook
#Check up time and current time (T2), to see whether the uptime = T2 - T1
#(T1 and T2 maybe not that accurate, maybe just check the up time at the end??)

#Shutdown.yml
#Ping the machine to make sure it is online
#Run playbook
#Ping the machine to see if it is shut down

#Update_upgrade.yml
#Run playbook
#Check update cache


echo "End of Ansible automation testing"