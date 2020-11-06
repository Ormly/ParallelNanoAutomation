#!/bin/bash

#Note: we need to run this script as user01, then we can ssh passwordlessly into johnny user
#account.

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

#check remote system
package_status=$(ssh johnny1 "dpkg -s $package_name") >/dev/null

#if package is already installed on remote systems abort the test
if [[ $package_status == *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is already installed $NC"
	echo "Install_apt_package.yml test aborting..."
#else install package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/playbooks/install_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if installed
	package_status=$(ssh johnny1 "dpkg -s $package_name") >/dev/null
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
package_status=$(ssh johnny1 "dpkg -s $package_name") >/dev/null

#if package is not installed abort the test
if [[ $package_status != *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is not installed $NC"
	echo "Remove_apt_package.yml test aborting..."
#else remove package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/playbooks/remove_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if no longer installed
	package_status=$(ssh johnny1 "dpkg -s $package_name") >/dev/null
	if [[ $package_status != *"Status: install ok installed"* ]]; then
		echo -e "$GREEN $package_name is now uninstalled $NC"
	else
		echo -e "$RED ERROR: $package_name still installed on certain nodes $NC"
		exit 4
	fi
fi

#Kickstart_compute_node.yml
echo "Testing Kickstart_computer_node.yml playbook..."
#Run playbook in a “pure johnny”
kickstart_status=$(ansible-playbook /nfs/scripts/automation/playbooks/kickstart_computer_node.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes)
#Run testing johnny script
johnny_test=$(./johnny_installation_testing.sh)
if [[ $? -eg 0 ]]; then
	echo -e "$GREEN Johnny installation succesful $NC"
else
	echo -e "$RED Johnny installation failed $NC"
	exit 5
fi

#Kickstart_control_node.yml
#echo "Testing Kickstart_control_node.yml playbook..."
#Run playbook in a “pure lisa”
kickstart_status=$(ansible-playbook /nfs/scripts/automation/playbooks/kickstart_control_node.yml -i "/nfs/scripts/automation/inventory.ini" -e target=controller)
#Run testing lisa script
lisa_test=$(./lisa_installation_testing.sh)
if [[ $? -eg 0 ]]; then
	echo -e "$GREEN Lisa installation succesful $NC"
else
	echo -e "$RED Lisa installation failed $NC"
	exit 5
fi

#Reboot.yml
echo "Testing Reboot.yml playbook..."
#Record current time (T1)
#Run playbook
#Check up time and current time (T2), to see whether the uptime = T2 - T1
#(T1 and T2 maybe not that accurate, maybe just check the up time at the end??)

#Shutdown.yml
echo "Testing Shutdown.yml playbook..."
#Ping the machine to make sure it is online
for var in 1 2 3 4 5 6 7 8
do
	johnnyX=$(host johnny$var) >/dev/null
	if [[ $? -eq 0 ]]; then
		ping -q -c 1 johnny$var ;
		if [[ $? -eq 0 ]]; then
			echo -e "$GREEN johnny$var reachable $NC"
		else
			echo -e "$RED ERROR: johnny$var unreachable $NC" 1>&2
			exit 12
		fi
	fi
done

#Run playbook
#Ping the machine to see if it is shut down

#Update_upgrade.yml
echo "Testing Update_upgrade.yml playbook..."
#Run playbook
update_status=$(ansible-playbook /nfs/scripts/automation/playbooks/update_upgrade.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes)
#Check update cache
if [[ $update_status == *"unreachable=1"* ]]; then #|| $update_status == *"failed=1"* ]]; then
	echo -e "$RED ERROR: All nodes not updated/upgraded $NC"
	exit 8
else
	echo -e "$GREEN All nodes succesfully updated/upgraded $NC"
fi

echo "End of Ansible automation testing"