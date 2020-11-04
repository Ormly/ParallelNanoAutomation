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

adduser "$username" --quiet --disabled-password --ingroup pjama-group --home /nfs/home/"$username" --gecos "$username"
echo "$username:$password" | chpasswd
make -C /var/yp

mkdir /nfs/home/"$username"/.ssh/
cp /root/.ssh/id_rsa /nfs/home/"$username"/.ssh/id_rsa
chown "$username":pjama-group /nfs/home/"$username" /nfs/home/"$username"/.ssh -R
chmod 600 /nfs/home/"$username"/.ssh/id_rsa