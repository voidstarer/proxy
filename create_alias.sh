#!/bin/bash

cd `dirname $0`

if [ ! -f ip_pool.conf ]; then
	echo "$0: ip_pool.conf not found"
	exit 1
fi

mainip=$(grep "^MainIP" -i ip_pool.conf | awk '{print $2}')
if [ -z "$mainip" ]; then
	echo "$0: MainIP not found in ip_pool.conf"
	exit 1
fi
iface=$(ip addr show | grep 199.188.88.42 | awk '{print $7}')
if [ -z "$iface" ]; then
	echo "$0: MainIP not found on any interface"
	exit 1
fi
echo "Creating alias on $iface"

count=0
grep "^Range" ip_pool.conf | while read x startip endip; do
	for ip in $(prips $startip $endip) ; do
		ifconfig $iface:$count $ip/32
		(( count++ )) ; 
	done
done
