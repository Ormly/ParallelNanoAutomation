#!/bin/bash
if [ "$1" != "" ]; then
	deluser --remove-home "$1"
	make -C /var/yp
else
	echo "No parameter given"
fi