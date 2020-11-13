#!/bin/bash
if [ "$#" == 1 ]; then
	deluser --remove-home "$1"
	make -C /var/yp
else
	echo "Incorrect number of parameters"
	exit 1
fi