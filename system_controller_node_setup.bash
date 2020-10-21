#!/bin/bash
#Updates, timezone and hostname
echo "Waiting for network..."
until ping -c1 www.google.com >/dev/null 2>&1; do :; done
apt update -y
apt full-upgrade -y
timedatectl set-timezone Europe/Berlin
hostnamectl set-hostname lisa

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
bobby:/nfs/scripts /nfs/scripts nfs rw,soft,x-systemd.automount 0 0
EOF
mkdir /nfs /nfs/home /nfs/scripts
mount bobby:/nfs/scripts /nfs/scripts

#Finishing up
apt-get install openssh-server build-essential git python3-pip libffi-dev -y

cd /nfs/scripts/ParallelNano_Lisa_Beacon
python3 setup.py install --user

cd /nfs/scripts/ParallelNano_Lisa_Lighthouse
python3 setup.py install --user
cd ~

cat > startup << EOF
python3 /nfs/scripts/ParallelNano_Lisa_Beacon/beacon_server/beacon_server_daemon.py
gunicorn -w 2 /nfs/scripts/ParallelNano_Lisa_Lighthouse/wsgi:app --daemon
EOF
chmod 777 startup
sudo ln -s startup /etc/profile.d/startup