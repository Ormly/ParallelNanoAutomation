#!/bin/bash
apt remove dnsmasq nfs-server portmap nis --purge -y

./remove_user johnny
./remove_user lisa

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
EOF

rm -r /nfs
rm -r /opt/mpiCommon

rm create_user
rm remove_user

rm /root/.ssh/id_rsa
rm /root/.ssh/known_hosts