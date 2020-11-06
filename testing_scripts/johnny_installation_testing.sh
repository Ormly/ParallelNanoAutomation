#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

#NFS Client:
#Check if proper mounts are accessable
mounts=$(showmount -e bobby)
echo "Tests starting---------------------------------"
echo "Testing NFS Client"
if [[ $mounts != *"/nfs/home"* || $mounts != *"/opt/mpiCommon"* ]]; then
        echo -e "$RED ERROR: NFS $NC" 1>&2
        exit 10
else
	echo -e "$GREEN NFS exports test passed $NC"
fi
#Check if permissions are properly set up in the shared dirs
echo "Testing NFS permissions"
new_file=$(cd /nfs/home && sudo touch test.txt)
if [[ ?$ ]]; then
	echo -e "$GREEN NFS permissions passed $NC"
	sudo rm /nfs/home/test.txt 
else
	echo -e "$RED NFS permissions failed $NC"
	exit 10
fi

#NIS Client:
#After installation, NIS needs to be running and a common Johhny user needs to be added
#To check if NIS is running, use the ypcat passwd file that needs to be accessible
nis_passwd_file=$(ypcat passwd)
echo "Testing NIS Client"
if [[ $? == *"0"* ]]; then
	echo -e "$RED ERROR: NIS passwd service not running properly $NC" 1>&2
	exit 11
else
	echo -e "$GREEN NIS passwd service running properly $NC"
fi

#DHCP & DNS Client:
#Ping outside
echo "Testing DHCP & DNS Client"
ping -q -c 1 8.8.8.8 ;
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Outside IP reachable $NC"
else
	echo -e "$RED ERROR: Outside IP unreachable $NC" 1>&2
	exit 12
fi

#Ping Bobby
ping -q -c 1 bobby ;
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Bobby reachable $NC"
else
	echo -e "$RED ERROR: Bobby unreachable $NC" 1>&2
	exit 12
fi

#Ping every Johnny
for var in 1 2 3 4 5 6 7 8
do
	johnnyX=$(host johnny0$var) >/dev/null
	if [[ $? -eq 0 ]]; then
		ping -q -c 1 johnny01 ;
		if [[ $? -eq 0 ]]; then
			echo -e "$GREEN Johnny0$var reachable $NC"
		else
			echo -e "$RED ERROR: Johnny0$var unreachable $NC" 1>&2
			exit 12
		fi
	fi
done

#Ping Lisa
ping -q -c 1 lisa ;
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Lisa reachable $NC"
else
	echo -e "$RED ERROR: Lisa unreachable $NC" 1>&2
	exit 12
fi


#MPI:
#Check if OpenMPI is installed properly, app checks done seperately
echo "Testing MPI Service"
if [[ $(mpiexec --version) ]]; then
	echo -e "$GREEN OpenMPI installed properly $NC"
else
	echo -e "$RED ERROR: OpenMPI not installed properly $NC" 1>&2
	exit 13
fi


#Login SSH:
#Check if SSH server is 
server_IP="localhost"
echo "Testing SSH Service"
if [[ $(nc -w 5 "$server_IP" 22 <<< "\0" ) =~ "OpenSSH" ]]; then
	echo -e "$GREEN SSH service running on $server_IP properly $NC"
else
	echo -e "$RED ERROR: SSH service not running properly $NC" 1>&2
	exit 14
fi

echo "End of tests-----------------------------------"