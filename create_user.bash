#!/bin/bash
#Takes can take in 0..2 parameters
#0 parameters - prompts for username and password
#1 parameter - user is created with username and password as parameter
#2 parameters - user is created with username as first parameter and password as second parameter
username=
password=

#If no parameters are given
if [ "$1" == "" ]; then
	echo -n "Enter a username: "
	read username
	echo -n "Enter a password: ["$username"] "
	read password
	if [ "$password" == "" ]; then
		password="$username"
	fi

#If username and password are given
elif [ "$1" != "" ] && [ "$2" != "" ]; then
	username="$1"
	password="$2"

#If username is given
else
	username="$1"
	password="$1"
fi

useradd "$username" -m -p $(openssl passwd -crypt "$password") -s /bin/bash -g pjama-group -d /nfs/home/"$username"
make -C /var/yp