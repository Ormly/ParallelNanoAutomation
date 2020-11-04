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
	echo -e "$RED ERROR: Ansible not installed $NC"
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
	ansible-playbook /nfs/scripts/automation/playbooks/install_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if installed
	package_status=$(dpkg -s $package_name) >/dev/null
	if [[ $package_status == *"Status: install ok installed"* ]]; then
		echo -e "$GREEN $package_name is now installed $NC"
	else
		echo -e "$RED ERROR: $package_name not installed on all nodes $NC"
		exit 3
	fi
fi


#Remove_apt_package.yml
echo "Testing Remove_apt_package.yml playbook..."
#Check the package is installed
package_status=$(dpkg -s $package_name) >/dev/null

#if package is not installed abort the test
if [[ $package_status != *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is not installed $NC"
	echo "Remove_apt_package.yml test aborting..."
#else remove package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/playbooks/remove_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if no longer installed
	package_status=$(dpkg -s $package_name) >/dev/null
	if [[ $package_status != *"Status: install ok installed"* ]]; then
		echo -e "$GREEN $package_name is now uninstalled $NC"
	else
		echo -e "$RED ERROR: $package_name still installed on all nodes $NC"
		exit 4
	fi
fi

#Kickstart_computer_node.yml
#echo "Testing Kickstart_computer_node.yml playbook..."
#Run playbook in a “pure johnny”
#Run testing johnny script

#Kickstart_control_node.yml
#echo "Testing Kickstart_control_node.yml playbook..."
#Run playbook in a “pure lisa”
#Run testing lisa script

#Reboot.yml
#echo "Testing Reboot.yml playbook..."
#Record current time (T1)
#Run playbook
#Check up time and current time (T2), to see whether the uptime = T2 - T1
#(T1 and T2 maybe not that accurate, maybe just check the up time at the end??)

#Shutdown.yml
#echo "Testing Shutdown.yml playbook..."
#Ping the machine to make sure it is online
#Run playbook
#Ping the machine to see if it is shut down

#Update_upgrade.yml
echo "Testing Update_upgrade.yml playbook..."
#Run playbook
update_status=$(ansible-playbook /nfs/scripts/automation/playbooks/update_upgrade.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes)
#Check update cache
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Nodes succesfully updated/upgraded $NC"
else
	echo -e "$RED ERROR: Nodes not updated/upgraded $NC"
	exit 8
fi

echo "End of Ansible automation testing"