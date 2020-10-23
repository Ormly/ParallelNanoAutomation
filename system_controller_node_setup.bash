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

cat > /etc/pam.d/common-session << EOF
#
# /etc/pam.d/common-session - session-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of modules that define tasks to be performed
# at the start and end of sessions of *any* kind (both interactive and
# non-interactive).
#
# As of pam 1.0.1-6, this file is managed by pam-auth-update by default.
# To take advantage of this, it is recommended that you configure any
# local modules either before or after the default block, and use
# pam-auth-update to manage selection of other modules.  See
# pam-auth-update(8) for details.

# here are the per-package modules (the "Primary" block)
session	[default=1]			pam_permit.so
# here's the fallback if no module succeeds
session	requisite			pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
session	required			pam_permit.so
# The pam_umask module will set the umask according to the system default in
# /etc/login.defs and user settings, solving the problem of different
# umask settings with different shells, display managers, remote sessions etc.
# See "man pam_umask".
session optional			pam_umask.so
# and here are more per-package modules (the "Additional" block)
session	required	pam_unix.so 
session	optional	pam_systemd.so 
# end of pam-auth-update config
session optional pam_mkhomedir.so skel=/etc/skel umask=077
EOF

#NFS setup
apt-get install nfs-common -y
cat > /etc/fstab << EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda1 during installation
UUID=4518aadf-afc5-4d05-bb53-cf351d9ad522 /               ext4    errors=remount-ro 0       1
/swapfile                                 none            swap    sw              0       0
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