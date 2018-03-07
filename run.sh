#!/bin/bash

cd `dirname $0`
iptables -t filter -N LB
iptables -t filter -I INPUT -j LB

./create_alias.sh
./pool.pl
./outgoing.pl
./allow_lb.pl

while true
do
	/etc/proxy/logging.pl 1 >> /var/log/proxy.log;
	/etc/proxy/main.pl >> /var/log/proxy.log;
	sleep 3
	/etc/proxy/logging.pl 2 >> /var/log/proxy.log;
	/etc/proxy/access.pl >> /var/log/proxy.log;	
	sleep 2
	/etc/proxy/logging.pl 3 >> /var/log/proxy.log;		
	sleep 30
done

