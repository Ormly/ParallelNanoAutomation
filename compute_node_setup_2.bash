#!/bin/bash
#MPI
apt install gcc g++ git make mpich -y
cd /opt/
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.5.tar.gz -O openmpi.tar.gz
tar -xzvf openmpi.tar.gz
rm openmpi.tar.gz
chmod +x openmpi-4.0.5/
cd openmpi-4.0.5/
./configure --prefix=/usr/local --enable-heterogeneous
make all install
ldconfig

#Give a hint to Ansible this is done
echo "Part 2 completed"