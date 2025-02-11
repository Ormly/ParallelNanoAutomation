#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

loop_num=()

#Start tests-----------------------------------
echo "Starting Ansible automation testing"

#check which Johnnys are all up and keep them as an iterable var
for var in 1 2 3 4 5 6 7 8
do
	johnnyX=$(host johnny0$var) >/dev/null
	if [[ $? -eq 0 ]]; then
		loop_num+=($var)
	fi
done

#1
#Check if ansile is installed
ansible_status=$(dpkg -s ansible)>/dev/null
if [[ $ansible_status == *"Status: install ok installed"* ]]; then
	echo -e "$GREEN Ansible installed $NC"
else
	echo -e "$RED ERROR: Ansible not installed $NC"
	exit 2
fi


#2
#Install_apt_package.yml
#Check the package is not install
echo "Testing Install_apt_package.yml playbook..."
echo "Please enter the name of the package you'd like to test, make sure it isn't installed already."
echo "Note that during the automation testing it will be removed again."
read package_name

#check remote system
package_status=$(ssh johnny0$loop_num "dpkg -s $package_name") >/dev/null

#if package is already installed on remote systems abort the test
if [[ $package_status == *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is already installed $NC"
	echo "Install_apt_package.yml test aborting..."
#else install package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/playbooks/install_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if installed
	for var in ${loop_num[@]}
	do
		package_status=$(ssh johnny0$var "dpkg -s $package_name") >/dev/null
		if [[ $package_status == *"Status: install ok installed"* ]]; then
			echo -e "$GREEN $package_name installed on johnny0$var $NC"
		else
			echo -e "$RED ERROR: $package_name not installed on johnny0$var $NC"
			exit 3
		fi
	done
	
fi


#3
#Remove_apt_package.yml
echo "Testing Remove_apt_package.yml playbook..."
#Check the package is installed
package_status=$(ssh johnny0$loop_num "dpkg -s $package_name") >/dev/null

#if package is not installed abort the test
if [[ $package_status != *"Status: install ok installed"* ]]; then
	echo -e "$RED $package_name is not installed $NC"
	echo "Remove_apt_package.yml test aborting..."
#else remove package and test result
else
	#Run playbook
	ansible-playbook /nfs/scripts/automation/playbooks/remove_apt_package.yml -i "/nfs/scripts/automation/inventory.ini" -e "target=nodes package=$package_name"
	#Check the package if no longer installed
	for var in ${loop_num[@]}
	do
		package_status=$(ssh johnny0$var "dpkg -s $package_name") >/dev/null
		if [[ $package_status != *"Status: install ok installed"* ]]; then
			echo -e "$GREEN $package_name is now uninstalled on johnny0$var $NC"
		else
			echo -e "$RED ERROR: $package_name still installed on johnny0$var $NC"
			exit 4
		fi
	done
fi


#4
#Kickstart_compute_node.yml
echo "Testing Kickstart_computer_node.yml playbook..."
#Run playbook in a “pure johnny”
#kickstart_status=$(ansible-playbook /nfs/scripts/automation/playbooks/kickstart_computer_node.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes)
#Run testing johnny script
for var in ${loop_num[@]}
do
	
	if [[ johnny_test=$(ssh johnny0$var "/nfs/scripts/automation/testing_scripts/johnny_installation_testing.sh") ]]; then
		echo -e "$GREEN Johnny installation succesful $NC"
	else
		echo -e "$RED Johnny installation failed $NC"
		exit 5
	fi
done

#5
#Kickstart_control_node.yml
echo "Testing Kickstart_control_node.yml playbook..."
#Run playbook in a “pure lisa”
#kickstart_status=$(ansible-playbook /nfs/scripts/automation/playbooks/kickstart_control_node.yml -i "/nfs/scripts/automation/inventory.ini" -e target=controller)
#Run testing lisa script
if [[ lisa_test=$(ssh lisa "/nfs/scripts/automation/testing_scripts/lisa_installation_testing.sh") ]]; then
	echo -e "$GREEN Lisa installation succesful $NC"
else
	echo -e "$RED Lisa installation failed $NC"
	exit 5
fi


#6
#Reboot.yml
echo "Testing Reboot.yml playbook..."
#record current uptime of nodes
uptime_vars=()

for n in ${loop_num[@]}
do
	temp1=$(ssh johnny0$n "uptime")
	temp1=${temp1##*"up"}
	uptime_vars+=${temp1%%,*}
done

#Run playbook
ansible-playbook /nfs/scripts/automation/playbooks/reboot.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes
#Check up-time
for m in ${loop_num[@]}
do
	temp2=$(ssh johnny0$m "uptime")
	temp2=${temp2##*"up"}
	temp2=${temp2%%,*}
	temp2=$(echo $temp2 | tr -d :)

	#convert values into nums
	uptime_vars[$m-1]=$(echo ${uptime_vars[$m-1]} | tr -d :)
	
	if [[ $temp2 -gt ${uptime_vars[$m-1]} ]]; then
		echo -e "$RED ERROR: Reboot not succesful $NC"
	else
		echo -e "$GREEN Reboot sucessful $NC"
	fi
done


#7
#Shutdown.yml
echo "Testing Shutdown.yml playbook..."
#Ping the machine to make sure it is online
johnny_up=()
for var in ${loop_num[@]}
do
	johnnyX=$(host johnny0$var) >/dev/null
	if [[ $? -eq 0 ]]; then
		ping -q -c 1 johnny0$var ;
		if [[ $? -eq 0 ]]; then
			echo -e "$johnny0$var: $GREEN UP $NC"
			johnny_up+=($var)
		else
			echo -e "$johnny0$var: $RED DOWN $NC"
		fi
	fi
done
#Run playbook
ansible-playbook /nfs/scripts/automation/playbooks/shutdown.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes
#Ping the machine to see if it is shut down
for t in ${johnny_up[@]}
do
	if [[ t -eq 1 ]]; then
		ping -q -c 1 johnny0$t
		if [[ $? == *"0"* ]]; then
			echo -e "$RED ERROR: johnny0$t not properly shut down $NC"
			exit 7
		fi
		
		echo -e "$johnny0$t: $GREEN SHUTDOWN $NC"
	fi
done

#Turn on the nodes again
ssh pjamaadmin@lisa 'cd /nfs/scripts/automation/lisa_scripts; for i in {1..8}; do echo "Turning on johnny0$i again"; python3 power_control.py power $i; done; exit'
echo "All johnnys turned back on, waiting for them to be responsive"
sleep 15

#8
#Update_upgrade.yml
echo "Testing Update_upgrade.yml playbook..."
#Run playbook
update_status=$(ansible-playbook /nfs/scripts/automation/playbooks/update_upgrade.yml -i "/nfs/scripts/automation/inventory.ini" -e target=nodes)
#Check update cache
if [[ $update_status == *"unreachable=1"* || $update_status == *"failed=1"* ]]; then
	echo -e "$RED ERROR: All nodes not updated/upgraded $NC"
	exit 8
else
	echo -e "$GREEN All nodes succesfully updated/upgraded $NC"
fi

echo "End of Ansible automation testing"
exit 0