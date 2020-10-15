#!/bin/bash
#Updates, timezone and hostname
echo "Waiting for network..."
until ping -c1 www.google.com >/dev/null 2>&1; do :; done
apt update -y
apt full-upgrade -y
timedatectl set-timezone Europe/Berlin
if [ "$1" != "" ]; then
	hostnamectl set-hostname $1
fi

#NIS setup
echo "nis nis/domain string pjama" > /tmp/nisinfo
debconf-set-selections /tmp/nisinfo
apt-get install nis -y
rm /tmp/nisinfo

cat > /etc/nsswitch.conf << EOF
#
# Example configuration of GNU Name Service Switch functionality.
# If you have the \`glibc-doc-reference' and \`info' packages installed, try:
# \`info libc "Name Service Switch"' for information about this file.

passwd:         compat nis
group:          compat nis
shadow:         compat
gshadow:        files

hosts:          files dns nis
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

cat > /etc/rc.local << EOF
# start nis related services
systemctl restart rpcbind
systemctl restart nis
exit 0
EOF

cat >> /etc/pam.d/common-session << EOF
session optional pam_mkhomedir.so skel=/etc/skel umask=077
EOF

#NFS setup
apt-get install nfs-common -y
cat >> /etc/fstab << EOF
# pjama related mounts
bobby:/nfs/home /nfs/home nfs rw,soft,x-systemd.automount 0 0
EOF
mkdir /nfs /nfs/home

#Finishing up
apt-get install openssh-server build-essential mpich -y

#MPI
apt install gcc g++ git make -y
cd /opt/
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.5.tar.gz -O openmpi.tar.gz
tar -xzvf openmpi.tar.gz
rm openmpi.tar.gz
chmod 777 open-mpi/
cd openmpi-4.0.5/
./configure --prefix=/usr/local --enable-heterogeneous
make all install
ldconfig

#Give a hint to Ansible this is done
echo "Script is done"