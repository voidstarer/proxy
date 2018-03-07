# proxy
Proxy configuration scripts

location: /etc/proxy
These files should be cloned at /etc/ location


During First or fresh boot, you should follow these steps:
	1) Install git:
		yum install git
		or
		apt-get install git
	2) git clone https://github.com/voidstarer/proxy.git to /etc/proxy
	3) Edit ip_pool.conf for MainIp and Range and allowed source and destination
	4) ./create_iptables_default_rules_save.sh > /etc/proxy/iptables.save
	5) ./create_alias.sh
	6) ./pool.pl
	7) ./outgoing.pl

During normal bootup:
/etc/rc.d/rc.local will:
	1) Restore iptables rules from /etc/proxy/iptables.save
	2) /etc/proxy/run.sh
