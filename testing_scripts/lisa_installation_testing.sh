#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

loop_num=(1 2 3 4 5 6 7 8)

echo "Start of tests---------------------------------"

#DHCP & DNS Server:
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


#Sensor testing
#Test temperature sensor to see if response is well formatted and sensor is running
#Well formatted => 
echo "Testing temperature and humidity sensor"
sensorRes=$(python3 /nfs/scripts/tempo/tempo/test_hdc1080.py)
re='^[0-9]+([.][0-9]+)?$'
if [[ $? -eq 0 ]]; then
	if [[ $sensorRes == *"Temperature = $re"* ]]
		echo -e "$GREEN Temperature properly formatted $NC"
	else 
		echo -e "$RED Temperature inaccurate"
		exit 15
	fi
	if [[ $sensorRes == *"Humidity = $re"* ]]
		echo -e "$GREEN Humidity properly formatted $NC"
	else 
		echo -e "$RED Humidity inaccurate"
		exit 15
	fi
fi

echo "End of tests-----------------------------------"