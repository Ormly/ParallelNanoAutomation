#!/bin/bash
#Set ip address

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] || [ "$4" == "" ]; then
	echo "Please enter external_type external_interface internal_type internal_interface"
	exit
fi

externaltype=$1
externalif=$2
internaltype=$3
internalif=$4

nmcli connection add con-name external type "$externaltype" ifname "$externalif" ipv4.method auto connection.autoconnect yes
nmcli connection add con-name internal type "$internaltype" ifname "$internalif" ipv4.method manual ipv4.addr 192.168.21.1/24 ipv4.dns "192.168.21.1,8.8.8.8"

mv /etc/sysctl.conf /etc/sysctl.conf.original

cat > /etc/sysctl.conf << EOF
net.ipv4.ip_forward=1
EOF

iptables -t nat -A POSTROUTING -o "$externalif" -j MASQUERADE
iptables -A FORWARD -i "$externalif" -o "$internalif" -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i "$internalif" -o "$externalif" -j ACCEPT
iptables-save > /etc/iptables.rules

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
sudo apt-get -y install iptables-persistent
echo PURGE | debconf-communicate packagename

until ping -c1 www.google.com >/dev/null 2>&1; do :; done

#Updates, timezone and hostname
apt update -y
apt full-upgrade -y
timedatectl set-timezone Europe/Berlin

#DHCP & DNS
apt-get install dnsmasq -y

systemctl stop systemd-resolved
cat > /etc/systemd/resolved.conf << EOF
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See resolved.conf(5) for details

[Resolve]
DNS=192.168.21.1
FallbackDNS=8.8.8.8
Domains=pjama
#LLMNR=no
MulticastDNS=no
DNSSEC=no
#Cache=yes
DNSStubListener=no
EOF

ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl start systemd-resolved

cat > /etc/hosts << EOF
127.0.0.1	localhost
192.168.21.1	bobby	bobby.pjama

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orginal
cat > /etc/dnsmasq.conf << EOF
#Global settings
domain-needed
bogus-priv
no-resolv
expand-hosts
filterwin2k

#Upstream nameservers
server=8.8.8.8
server=8.8.4.4

#Domain name
domain=pjama
local=/pjama/

listen-address=127.0.0.1
listen-address=192.168.21.1

interface="$internalif"

#DHCP options
dhcp-range=192.168.21.50,192.168.21.200,12h
dhcp-lease-max=150
dhcp-option=option:dns-server,192.168.21.1
dhcp-option=option:netmask,255.255.255.0
EOF

#NFS Server
apt-get install nfs-server -y
mkdir /nfs /nfs/home /nfs/scripts /opt/mpiCommon

cat > /etc/exports << EOF
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/nfs/home *(rw,sync,no_root_squash,no_subtree_check)
/nfs/scripts *(rw,sync,no_root_squash,no_subtree_check)
/opt/mpiCommon *(rw,sync,no_root_squash,no_subtree_check)
EOF

service nfs-kernel-server restart
exportfs -ra

#NIS Server
echo "nis nis/domain string pjama" > /tmp/nisinfo
debconf-set-selections /tmp/nisinfo
apt-get install portmap nis -y
rm /tmp/nisinfo
echo PURGE | debconf-communicate packagename

cat > /etc/default/nis << EOF
#
# /etc/defaults/nis	Configuration settings for the NIS daemons.
#

# Are we a NIS server and if so what kind (values: false, slave, master)?
NISSERVER=master

# Are we a NIS client?
NISCLIENT=false

# Location of the master NIS password file (for yppasswdd).
# If you change this make sure it matches with /var/yp/Makefile.
YPPWDDIR=/etc

# Do we allow the user to use ypchsh and/or ypchfn ? The YPCHANGEOK
# fields are passed with -e to yppasswdd, see it's manpage.
# Possible values: "chsh", "chfn", "chsh,chfn"
YPCHANGEOK=chsh

# NIS master server.  If this is configured on a slave server then ypinit
# will be run each time NIS is started.
NISMASTER=

# Additional options to be given to ypserv when it is started.
YPSERVARGS=

# Additional options to be given to ypbind when it is started.  
YPBINDARGS=-no-dbus

# Additional options to be given to yppasswdd when it is started.  Note
# that if -p is set then the YPPWDDIR above should be empty.
YPPASSWDDARGS=

# Additional options to be given to ypxfrd when it is started. 
YPXFRDARGS=
EOF

cat > /etc/ypserv.securenets << EOF
#
# securenets	This file defines the access rights to your NIS server
#		for NIS clients (and slave servers - ypxfrd uses this
#		file too). This file contains netmask/network pairs.
#		A clients IP address needs to match with at least one
#		of those.
#
#		One can use the word "host" instead of a netmask of
#		255.255.255.255. Only IP addresses are allowed in this
#		file, not hostnames.
#
# Always allow access for localhost
255.0.0.0	127.0.0.0

# This line gives access to everybody. PLEASE ADJUST!
#0.0.0.0		0.0.0.0
255.255.255.0	192.168.21.0
EOF

cat > /var/yp/Makefile << EOF
#
# Makefile for the NIS databases
#
# This Makefile should only be run on the NIS master server of a domain.
# All updated maps will be pushed to all NIS slave servers listed in the
# /var/yp/ypservers file. Please make sure that the hostnames of all
# NIS servers in your domain are listed in /var/yp/ypservers.
#
# This Makefile can be modified to support more NIS maps if desired.
#

# Set the following variable to "-b" to have NIS servers use the domain
# name resolver for hosts not in the current domain. This is only needed,
# if you have SunOS slave YP server, which gets here maps from this
# server. The NYS YP server will ignore the YP_INTERDOMAIN key.
#B=-b
B=

# If we have only one server, we don't have to push the maps to the
# slave servers (NOPUSH=true). If you have slave servers, change this
# to "NOPUSH=false" and put all hostnames of your slave servers in the file
# /var/yp/ypservers.
NOPUSH=true

# Specify any additional arguments to be supplied when invoking yppush.
# For example, the --port option may be used to allow operation with port
# based firewalls.
YPPUSHARGS=

# We do not put password entries with lower UIDs (the root and system
# entries) in the NIS password database, for security. MINUID is the
# lowest uid that will be included in the password maps. If you
# create shadow maps, the UserID for a shadow entry is taken from
# the passwd file. If no entry is found, this shadow entry is
# ignored.
# MINGID is the lowest gid that will be included in the group maps.
MINUID=1000
MINGID=1000

# Similarly, we also define a MAXUID and MAXGID specifying the maximum
# user ID and group ID which will be exported.
MAXUID=4294967295
MAXGID=4294967295

# Don't export this uid/guid (nfsnobody).
# Set to 0 if you want to
NFSNOBODYUID=65534
NFSNOBODYGID=65534

# Should we merge the passwd file with the shadow file ?
# MERGE_PASSWD=true|false
MERGE_PASSWD=true

# Should we merge the group file with the gshadow file ?
# MERGE_GROUP=true|false
MERGE_GROUP=true

# These are commands which this Makefile needs to properly rebuild the
# NIS databases. Don't change these unless you have a good reason.
AWK = /usr/bin/awk
MAKE = /usr/bin/make
UMASK = umask 066

#
# These are the source directories for the NIS files; normally
# that is /etc but you may want to move the source for the password
# and group files to (for example) /var/yp/ypfiles. The directory
# for passwd, group and shadow is defined by YPPWDDIR, the rest is
# taken from YPSRCDIR.
#
YPSRCDIR = /etc
YPPWDDIR = /etc
YPBINDIR = /usr/lib/yp
YPSBINDIR = /usr/sbin
YPDIR = /var/yp
YPMAPDIR = \$(YPDIR)/\$(DOMAIN)

# These are the files from which the NIS databases are built. You may edit
# these to taste in the event that you wish to keep your NIS source files
# seperate from your NIS server's actual configuration files.
#
GROUP       = \$(YPPWDDIR)/group
PASSWD      = \$(YPPWDDIR)/passwd
SHADOW	    = \$(YPPWDDIR)/shadow
GSHADOW     = \$(YPPWDDIR)/gshadow
ADJUNCT     = \$(YPPWDDIR)/passwd.adjunct
#ALIASES     = \$(YPSRCDIR)/aliases  # aliases could be in /etc or /etc/mail
ALIASES     = /etc/mail/aliases
ETHERS      = \$(YPSRCDIR)/ethers     # ethernet addresses (for rarpd)
BOOTPARAMS  = \$(YPSRCDIR)/bootparams # for booting Sun boxes (bootparamd)
HOSTS       = \$(YPSRCDIR)/hosts
NETWORKS    = \$(YPSRCDIR)/networks
PRINTCAP    = \$(YPSRCDIR)/printcap
PROTOCOLS   = \$(YPSRCDIR)/protocols
PUBLICKEYS  = \$(YPSRCDIR)/publickey
RPC 	    = \$(YPSRCDIR)/rpc
SERVICES    = \$(YPSRCDIR)/services
NETGROUP    = \$(YPSRCDIR)/netgroup
NETID	    = \$(YPSRCDIR)/netid
AMD_HOME    = \$(YPSRCDIR)/am-utils/amd.home
AUTO_MASTER = \$(YPSRCDIR)/auto.master
AUTO_HOME   = \$(YPSRCDIR)/auto.home
AUTO_LOCAL  = \$(YPSRCDIR)/auto.local
TIMEZONE    = \$(YPSRCDIR)/timezone
LOCALE      = \$(YPSRCDIR)/locale
NETMASKS    = \$(YPSRCDIR)/netmasks

YPSERVERS = \$(YPDIR)/ypservers	# List of all NIS servers for a domain

target: Makefile
	@test ! -d \$(LOCALDOMAIN) && mkdir \$(LOCALDOMAIN) ; \\
	cd \$(LOCALDOMAIN)  ; \\
	\$(NOPUSH) || \$(MAKE) -f ../Makefile ypservers; \\
	\$(MAKE) -f ../Makefile all

# If you don't want some of these maps built, feel free to comment
# them out from this list.

ALL =	passwd group hosts rpc services netid protocols netgrp
#ALL +=	publickey mail ethers bootparams printcap
#ALL +=	amd.home auto.master auto.home auto.local
#ALL +=	timezone locale networks netmasks

# Autodetect /etc/shadow if it's there
ifneq (\$(wildcard \$(SHADOW)),)
ALL += shadow
endif

# Autodetect /etc/passwd.adjunct if it's there
ifneq (\$(wildcard \$(ADJUNCT)),)
ALL += passwd.adjunct
endif
                                                                              
all:   \$(ALL)
                                                                                


########################################################################
#                                                                      #
#  DON'T EDIT ANYTHING BELOW IF YOU DON'T KNOW WHAT YOU ARE DOING !!!  #
#                                                                      #
########################################################################

DBLOAD = \$(YPBINDIR)/makedbm --no-limit-check -c -m \`\$(YPBINDIR)/yphelper --hostname\`
MKNETID = \$(YPBINDIR)/mknetid
YPPUSH = \$(YPSBINDIR)/yppush \$(YPPUSHARGS)
MERGER = \$(YPBINDIR)/yphelper
DOMAIN = \`basename \\\`pwd\\\`\`
LOCALDOMAIN = \`/bin/domainname\`
REVNETGROUP = \$(YPBINDIR)/revnetgroup
CREATE_PRINTCAP = \$(YPBINDIR)/create_printcap

ethers:	   	ethers.byname ethers.byaddr
hosts:	   	hosts.byname hosts.byaddr
networks:  	networks.byaddr networks.byname
protocols: 	protocols.bynumber protocols.byname
rpc:	   	rpc.byname rpc.bynumber
services:  	services.byname services.byservicename
passwd:    	passwd.byname passwd.byuid
group:     	group.byname group.bygid
shadow:	   	shadow.byname
passwd.adjunct:	passwd.adjunct.byname
netid:	   	netid.byname
netgrp:	   	netgroup netgroup.byhost netgroup.byuser
publickey: 	publickey.byname
mail:	   	mail.aliases
timezone:      timezone.byname
locale:                locale.byname
netmasks:      netmasks.byaddr

ypservers: \$(YPSERVERS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#") print \$\$0"\\t"\$\$0 }' \\
	    \$(YPSERVERS) | \$(DBLOAD) -i \$(YPSERVERS) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

\$(YPSERVERS):
	@echo -n "Generating \$*..."
	@uname -n > \$(YPSERVERS)

bootparams: \$(BOOTPARAMS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#" && \$\$1 != "+") \\
		print \$\$0 }' \$(BOOTPARAMS) | \$(DBLOAD) -r -i \$(BOOTPARAMS) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


ethers.byname: \$(ETHERS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#" && \$\$1 != "+") \\
		print \$\$2"\\t"\$\$0 }' \$(ETHERS) | \$(DBLOAD) -r -i \$(ETHERS) \\
						-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


ethers.byaddr: \$(ETHERS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#" && \$\$1 != "+") \\
		print \$\$1"\\t"\$\$0 }' \$(ETHERS) | \$(DBLOAD) -r -i \$(ETHERS) \\
						-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


netgroup: \$(NETGROUP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#" && \$\$1 != "+") \\
		print \$\$0 }' \$(NETGROUP) | \$(DBLOAD) -i \$(NETGROUP) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


netgroup.byhost: \$(NETGROUP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(REVNETGROUP) -h < \$(NETGROUP) | \$(DBLOAD) -i \$(NETGROUP) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


netgroup.byuser: \$(NETGROUP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(REVNETGROUP) -u < \$(NETGROUP) | \$(DBLOAD) -i \$(NETGROUP) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


hosts.byname: \$(HOSTS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '/^[0-9]/ { for (n=2; n<=NF && \$\$n !~ "#"; n++) \\
		print \$\$n"\\t"\$\$0 }' \$(HOSTS) | \$(DBLOAD) -r \$(B) -l \\
			-i \$(HOSTS) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

hosts.byaddr: \$(HOSTS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") print \$\$1"\\t"\$\$0 }' \\
	   \$(HOSTS) | \$(DBLOAD) -r \$(B) -i \$(HOSTS) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


networks.byname: \$(NETWORKS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if(\$\$1 !~ "#" && \$\$1 != "") { print \$\$1"\\t"\$\$0; \\
		 for (n=3; n<=NF && \$\$n !~ "#"; n++) print \$\$n"\\t"\$\$0 \\
			}}' \$(NETWORKS) | \$(DBLOAD) -r -i \$(NETWORKS) \\
			 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


networks.byaddr: \$(NETWORKS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") print \$\$2"\\t"\$\$0 }' \\
		 \$(NETWORKS) | \$(DBLOAD) -r -i \$(NETWORKS) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


protocols.byname: \$(PROTOCOLS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") { print \$\$1"\\t"\$\$0; \\
		for (n=3; n<=NF && \$\$n !~ "#"; n++) \\
		print \$\$n"\\t"\$\$0}}' \$(PROTOCOLS) | \$(DBLOAD) -r -i \\
			\$(PROTOCOLS) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


protocols.bynumber: \$(PROTOCOLS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") print \$\$2"\\t"\$\$0 }' \\
		\$(PROTOCOLS) | \$(DBLOAD) -r -i \$(PROTOCOLS) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


rpc.byname: \$(RPC) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#"  && \$\$1 != "") { print \$\$1"\\t"\$\$0; \\
		for (n=3; n<=NF && \$\$n !~ "#"; n++)  print \$\$n"\\t"\$\$0 \\
		  }}' \$(RPC) | \$(DBLOAD) -r -i \$(RPC) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


rpc.bynumber: \$(RPC) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") print \$\$2"\\t"\$\$0 }' \$(RPC) \\
		| \$(DBLOAD) -r -i \$(RPC) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


services.byname: \$(SERVICES) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") print \$\$2"\\t"\$\$0 }' \\
		\$(SERVICES) | \$(DBLOAD) -r -i \$(SERVICES) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

services.byservicename: \$(SERVICES) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 !~ "#" && \$\$1 != "") { \\
		split(\$\$2,A,"/") ; TMP = "/" A[2] ; \\
		print \$\$1 TMP"\\t"\$\$0 ; \\
		if (! seen[\$\$1]) { seen[\$\$1] = 1 ; print \$\$1"\\t"\$\$0 ; } \\
		for (N = 3; N <= NF && \$\$N !~ "#" ; N++) { \\
			if (\$\$N !~ "#" && \$\$N != "") print \$\$N TMP"\\t"\$\$0 ; \\
			if (! seen[\$\$N]) { seen[\$\$N] = 1 ; print \$\$N"\\t"\$\$0 ; } \\
		} } } ' \\
		\$(SERVICES) | \$(DBLOAD) -r -i \$(SERVICES) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


ifeq (x\$(MERGE_PASSWD),xtrue)
passwd.byname: \$(PASSWD) \$(SHADOW) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(MERGER) -p \$(PASSWD) \$(SHADOW) | \\
	   \$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINUID) && \$\$3 <= \$(MAXUID) && \$\$3 != \$(NFSNOBODYUID) ) \\
	   print \$\$1"\\t"\$\$0 }' | \$(DBLOAD) -i \$(PASSWD) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

passwd.byuid: \$(PASSWD) \$(SHADOW) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(MERGER) -p \$(PASSWD) \$(SHADOW) | \\
	   \$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINUID) && \$\$3 <= \$(MAXUID) && \$\$3 != \$(NFSNOBODYUID) ) \\
	   print \$\$3"\\t"\$\$0 }' | \$(DBLOAD) -i \$(PASSWD) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

# Don't build a shadow map !
shadow.byname:
	@echo "Updating \$@... Ignored -> merged with passwd"

else

passwd.byname: \$(PASSWD) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINUID) && \$\$3 <= \$(MAXUID) && \$\$3 != \$(NFSNOBODYUID) ) \\
	   print \$\$1"\\t"\$\$0 }' \$(PASSWD) | \$(DBLOAD) -i \$(PASSWD) \\
		-o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

passwd.byuid: \$(PASSWD) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINUID) && \$\$3 <= \$(MAXUID) && \$\$3 != \$(NFSNOBODYUID) ) \\
	   print \$\$3"\\t"\$\$0 }' \$(PASSWD) | \$(DBLOAD) -i \$(PASSWD) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

shadow.byname: \$(SHADOW) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '{ if (FILENAME ~ /shadow\$\$/) { \\
		if (UID[\$\$1] >= \$(MINUID) && UID[\$\$1] != \$(NFSNOBODYUID)) print \$\$1"\\t"\$\$0; \\
			} else UID[\$\$1] = \$\$3; }' \$(PASSWD) \$(SHADOW) \\
		| \$(DBLOAD) -s -i \$(SHADOW) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@
endif

passwd.adjunct.byname: \$(ADJUNCT) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" ) print \$\$1"\\t"\$\$0 }' \\
		\$(ADJUNCT) | \$(DBLOAD) -s -i \$(ADJUNCT) -o \$(YPMAPDIR)/\$@ - \$@
	@chmod 700 \$(YPDIR)/\$(DOMAIN)/\$@*
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

ifeq (x\$(MERGE_GROUP),xtrue)
group.byname: \$(GROUP) \$(GSHADOW) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(MERGER) -g \$(GROUP) \$(GSHADOW) | \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINGID) && \$\$3 <= \$(MAXGID) && \$\$3 != \$(NFSNOBODYGID) ) \\
	print \$\$1"\\t"\$\$0 }' | \$(DBLOAD) -i \$(GROUP) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

group.bygid: \$(GROUP) \$(GSHADOW) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(MERGER) -g \$(GROUP) \$(GSHADOW) | \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINGID) && \$\$3 <= \$(MAXGID) && \$\$3 != \$(NFSNOBODYGID) ) \\
	print \$\$3"\\t"\$\$0 }' | \$(DBLOAD) -i \$(GROUP) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

else

group.byname: \$(GROUP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINGID) && \$\$3 <= \$(MAXGID) && \$\$3 != \$(NFSNOBODYGID) ) \\
					print \$\$1"\\t"\$\$0 }' \$(GROUP) \\
		| \$(DBLOAD) -i \$(GROUP) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

group.bygid: \$(GROUP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(UMASK); \\
	\$(AWK) -F: '!/^[-+#]/ { if (\$\$1 != "" && \$\$3 >= \$(MINGID) && \$\$3 <= \$(MAXGID) && \$\$3 != \$(NFSNOBODYGID) ) \\
					print \$\$3"\\t"\$\$0 }' \$(GROUP) \\
		| \$(DBLOAD) -i \$(GROUP) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@
endif

\$(NETID):
netid.byname: \$(GROUP) \$(PASSWD) \$(HOSTS) \$(NETID) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(MKNETID) -q -p \$(PASSWD) -g \$(GROUP) -h \$(HOSTS) -d \$(DOMAIN) \\
		-n \$(NETID) | \$(DBLOAD) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


mail.aliases: \$(ALIASES) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ \\
			if (\$\$1 ~ "^#.*") \\
				next; \\
			if (\$\$1 == "" || \$\$1 == "+") { \\
				if (line != "") \\
					{print line; line = "";} \\
				next; \\
			} \\
			if (\$\$0 ~ /^[[:space:]]/) \\
				line = line \$\$0; \\
			else { \\
				if (line != "") \\
					{print line; line = "";} \\
				line = \$\$0; \\
			} \\
		} \\
		END {if (line != "") print line}' \\
		\$(ALIASES) | \$(DBLOAD) --aliases \\
			-i \$(ALIASES) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


publickey.byname: \$(PUBLICKEYS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if(\$\$1 !~ "#" && \$\$1 != "") { print \$\$1"\\t"\$\$2 }}' \\
		\$(PUBLICKEYS) | \$(DBLOAD) -i \$(PUBLICKEYS) \\
		 -o \$(YPMAPDIR)/\$@ - \$@
	@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


printcap: \$(PRINTCAP) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(CREATE_PRINTCAP) < \$(PRINTCAP) | \\
		\$(DBLOAD) -i \$(PRINTCAP) -o \$(YPMAPDIR)/\$@ - \$@
	@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


auto.master: \$(AUTO_MASTER) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	-@sed -e "/^#/d" -e s/#.*\$\$// \$(AUTO_MASTER) | \$(DBLOAD) \\
		-i \$(AUTO_MASTER) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

auto.home: \$(AUTO_HOME) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	-@sed -e "/^#/d" -e s/#.*\$\$// \$(AUTO_HOME) | \$(DBLOAD) \\
		-i \$(AUTO_HOME) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


auto.local: \$(AUTO_LOCAL) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	-@sed -e "/^#/d" -e s/#.*\$\$// \$(AUTO_LOCAL) | \$(DBLOAD) \\
		-i \$(AUTO_LOCAL) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


amd.home: \$(AMD_HOME) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	-@sed -e "s/#.*\$\$//" -e "/^\$\$/d" \$(AMD_HOME) | \\
	\$(AWK) '{\\
		for (i = 1; i <= NF; i++)\\
		   if (i == NF) { \\
		      if (substr(\$\$i, length(\$\$i), 1) == "\\\\") \\
	                   printf("%s", substr(\$\$i, 1, length(\$\$i) -1)); \\
	               else \\
			  printf("%s\\n",\$\$i); \\
	              } \\
		   else \\
		      printf("%s ",\$\$i);\\
		}' | \$(DBLOAD) -i \$(AMD_HOME) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@

timezone.byname: \$(TIMEZONE) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#") \\
		print \$\$2"\\t"\$\$0 }' \$(TIMEZONE) | \$(DBLOAD) \\
			-r -i \$(TIMEZONE) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


locale.byname: \$(LOCALE) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#") \\
	     print \$\$2"\\t"\$\$0"\\n"\$\$1"\\t"\$\$2"\\t"\$\$1 }' \$(LOCALE) | \$(DBLOAD) \\
		-r -i \$(LOCALE) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@


netmasks.byaddr: \$(NETMASKS) \$(YPDIR)/Makefile
	@echo "Updating \$@..."
	@\$(AWK) '{ if (\$\$1 != "" && \$\$1 !~ "#") \\
		print \$\$1"\\t"\$\$2 }' \$(NETMASKS) | \$(DBLOAD) \\
			-r -i \$(NETMASKS) -o \$(YPMAPDIR)/\$@ - \$@
	-@\$(NOPUSH) || \$(YPPUSH) -d \$(DOMAIN) \$@
EOF

systemctl restart nis

cat > create_user << EOF
#!/bin/bash
#Takes can take in 0..2 parameters
#0 parameters - prompts for username and password
#1 parameter - user is created with username and password as parameter
#2 parameters - user is created with username as first parameter and password as second parameter
username=
password=

#If no parameters are given
if [ "\$1" == "" ]; then
	echo -n "Enter a username: "
	read username
	echo -n "Enter a password: ["\$username"] "
	read password
	if [ "\$password" == "" ]; then
		password="\$username"
	fi

#If username and password are given
elif [ "\$1" != "" ] && [ "\$2" != "" ]; then
	username="\$1"
	password="\$2"

#If username is given
else
	username="\$1"
	password="\$1"
fi

adduser "\$username" --quiet --disabled-password --ingroup pjama-group --home /nfs/home/"\$username" --gecos "\$username"
echo "\$username:\$password" | chpasswd
make -C /var/yp
EOF

cat > remove_user << EOF
#!/bin/bash
if [ "\$1" != "" ]; then
	deluser --remove-home "\$1"
	make -C /var/yp
else
	echo "No parameter given"
fi
EOF

chmod 777 create_user
chmod 777 remove_user

# Add user johnny to database
addgroup --gid 1110 pjama-group
./create_user johnny
./create_user lisa

apt-get install git -y

mkdir -p /root/.ssh

#touch id_rsa
cat > id_rsa << EOF
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
EOF

chmod 000 id_rsa

ssh-add id_rsa
eval $(ssh-agent -s)

#touch known_hosts
cat > known_hosts << EOF
|1|P7EV6eBuuhK88GGn/bZZsWeQAHs=|Bz18lfOREtpVRcWHMIVthMQKWWE= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
|1|9fw8X2E2/Ic7bc63OGLf9ABuyOQ=|Tr/1Q7FzP+oLh4e2qLC2gD9yug0= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
|1|y5U42fljybY+cedPxOndkAY5s0Q=|ZtdYfVuh7P9psIQJzaFGYS6fO4c= ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
EOF

mkdir -p /root/.ssh
mv id_rsa /root/.ssh/id_rsa
mv known_hosts /root/.ssh/known_hosts

chmod 777 /nfs/scripts
cd /nfs/scripts
git clone git@github.com:Ormly/ParallelNano_Lisa_Beacon.git
git clone git@github.com:Ormly/ParallelNano_Lisa_Beacon_Agent.git
git clone git@github.com:Ormly/ParallelNano_Lisa_Lighthouse.git
git clone git@github.com:Ormly/ParallelNanoAutomation.git
git clone git@github.com:Ormly/ParallelNano_Lisa_Tempo.git
cd ~

apt-get install software-properties-common -y
apt-add-repository ppa:ansible/ansible -y
apt-get install openssh-server build-essential mpich ansible -y

reboot