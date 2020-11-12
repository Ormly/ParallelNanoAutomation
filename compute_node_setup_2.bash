#!/bin/bash
#MPI
apt install gcc g++ git make mpich -y
cd /opt/
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.5.tar.gz -O openmpi.tar.gz
tar -xzvf openmpi.tar.gz
rm openmpi.tar.gz
chmod +x -R openmpi-4.0.5/
cd openmpi-4.0.5/
./configure --prefix=/usr/local --with-cuda
make all install
ldconfig
export PATH="/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64"
chown pjamaadmin:pjama-group /dev -R
cd /dev
chown pjamaadmin:pjama-group -R .
chown pjamaadmin:pjama-group /usr/local/cuda
cd /usr/local/cuda
chown pjamaadmin:pjama-group -R .

#Give a hint to Ansible this is done
echo "Script is done"