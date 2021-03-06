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

cat << EOF
# Generated by iptables-save v1.4.21 on Wed Jul  5 14:00:49 2017
*nat
:PREROUTING ACCEPT [293476533:17163668727]
:INPUT ACCEPT [14250591:733115338]
:OUTPUT ACCEPT [14689203:918789665]
:POSTROUTING ACCEPT [16463995:1026889999]
COMMIT
# Completed on Wed Jul  5 14:00:49 2017
# Generated by iptables-save v1.4.21 on Wed Jul  5 14:00:49 2017
*filter
:INPUT DROP [7143038:399473837]
:FORWARD ACCEPT [68822:3755300]
:OUTPUT ACCEPT [9978376:3091832824]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
EOF
for ip in $(grep "^AllowedSourceIp" ip_pool.conf | cut  -b 16-); do
	echo -A INPUT -s $ip -j ACCEPT
done

for port in $(grep "^AllowedMainIpTcpPorts" ip_pool.conf | cut  -b 22-); do
	echo -A INPUT -d $mainip -p tcp -m tcp --dport $port -j ACCEPT
done

cat << EOF
-A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A INPUT -i lo -j ACCEPT
COMMIT
# Completed on Wed Jul  5 14:00:49 2017
EOF
