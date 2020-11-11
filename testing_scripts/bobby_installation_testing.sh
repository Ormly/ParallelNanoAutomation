#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

loop_num=(1 2 3 4 5 6 7 8)

#NFS Server:
#Check if proper mounts are available
mounts=$(showmount -e bobby)
echo "Tests starting---------------------------------"
echo "Testing NFS Server"
if [[ $mounts != *"/nfs"* || $mounts != *"/opt/mpiCommon"* ]]; then
        echo -e "$RED ERROR: NFS $NC" 1>&2
        exit 10
else
	echo -e "$GREEN NFS exports test passed $NC"
fi

#NIS Server:
#After installation, the rpcbind service needs to be up and running
#To check if NIS is running, use the rpcbind service
nis_rpcbind_status=$(systemctl status rpcbind) >/dev/null
echo "Testing NIS Server"
if [[ $nis_rpcbind_status != *"Active: active"* ]]; then
	echo -e "$RED ERROR: NIS serivce not running properly $NC" 1>&2
	exit 11
else
	echo -e "$GREEN NIS service running properly $NC"
fi

#DHCP & DNS Server:
#Ping outside
echo "Testing DHCP & DNS Server"
ping -q -c 1 8.8.8.8 ;
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Outside IP reachable $NC"
else
	echo -e "$RED ERROR: Outside IP unreachable $NC" 1>&2
	exit 12
fi

#Ping every Johnny
for var in ${loop_num[@]}
do
	johnnyX=$(host johnny0$var) >/dev/null
	if [[ $? -eq 0 ]]; then
		ping -q -c 1 johnny0$var ;
		if [[ $? -eq 0 ]]; then
			echo -e "$GREEN johnny0$var reachable $NC"
		else
			echo -e "$RED ERROR: johnny0$var unreachable $NC" 1>&2
			exit 12
		fi
	fi
done

#Ping Lisa
ping -q -c 1 lisa ;
if [[ $? -eq 0 ]]; then
	echo -e "$GREEN Lisa reachable $NC"
else
	echo -e "$RED ERROR: Lisa IP unreachable $NC" 1>&2
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
server_IP="bobby"
echo "Testing SSH Service"
if [[ $(nc -w 5 "$server_IP" 22 <<< "\0" ) =~ "OpenSSH" ]]; then
	echo -e "$GREEN SSH service running on $server_IP properly $NC"
else
	echo -e "$RED ERROR: SSH service not running properly $NC" 1>&2
	exit 14
fi

echo "End of tests-----------------------------------"
exit 0