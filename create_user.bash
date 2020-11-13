#!/bin/bash
#Takes can take in 0..2 parameters
#0 parameters - prompts for username and password
#1 parameter - user is created with username and password as parameter
#2 parameters - user is created with username as first parameter and password as second parameter
username=
password=
is_admin=0
is_user=0

while getopts ":uah" opt; do
	case $opt in
		u)	is_user=1;;
		a)	is_admin=1;;
		h)	echo "-a for admin and -u for user"
		    exit 1;;
		*)  echo "Invalid argument"
		    exit 1;;
	esac
done
shift $((OPTIND-1))

#If no parameters are given
if [ "$#" == 0 ]; then
	echo -n "Enter a username: "
	read -r username
	echo -n "Enter a password: [$username] "
	read -r password
	if [ "$password" == "" ]; then
		password="$username"
	fi

#If username is given
elif [ "$#" == 1 ]; then
	username="$1"
	password="$1"

#If username and password are given
elif [ "$#" == 2 ]; then
	username="$1"
	password="$2"
	
else
	exit 1
fi

adduser "$username" --quiet --disabled-password --ingroup pjama-group --home /nfs/home/"$username" --gecos "$username" || exit 1
echo "$username:$password" | chpasswd
if [ $is_user == 1 ]; then
	usermod -a -G pjama-user "$username"
fi
if [ $is_admin == 1 ]; then
	usermod -a -G pjama-admin "$username"
fi
make -C /var/yp

mkdir /nfs/home/"$username"/.ssh/
cd /nfs/home/"$username"/.ssh/
cp /root/.ssh/id_rsa git_rsa
cat > config << EOF
Host github.com
	IdentityFile ~/.ssh/git_rsa
	User git
EOF
ssh-keygen -f id_rsa -q -N ""
cp id_rsa.pub authorized_keys
chown "$username":pjama-group /nfs/home/"$username" /nfs/home/"$username"/.ssh -R
chmod 600 authorized_keys git_rsa id_rsa
chmod 644 config id_rsa.pub