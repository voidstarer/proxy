#!/usr/bin/perl -w
use strict;
use warnings;
use DBI;
use DateTime;
use Time::Piece::MySQL;

#MySQL Connection
my $dbh = DBI->connect('dbi:mysql:squid','squid','testing')
or die "Connection Error: $DBI::errstr\n";

my $sql = "SELECT * FROM squid_status RIGHT JOIN squid_servers ON squid_status.proxy_id=squid_servers.proxy_id";
my $sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";

my $mysql_dt = localtime->mysql_datetime;


while (my @row = $sth->fetchrow_array) {

	my ($id,$proxy_id, $status,$proxy_ip,$proxy_port,$process,$idSS, $proxy_idSS, $proxy_ipSS,$proxy_portSS,$conNum) = @row;

	if(defined $id){
			my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server deleted','$mysql_dt','$proxy_ip','$proxy_port','','2')";
			my $sth_log = $dbh->prepare($sql_log);
			$sth_log->execute;
			print "[".localtime()."]"." Proxy Server deleted at ".$proxy_ip.":".$proxy_port."\n";
			my $sqlCheckStatus = "SELECT * FROM access_status WHERE proxy_id=$proxy_id";	
			my $sthCheckStatus = $dbh->prepare($sqlCheckStatus);
			$sthCheckStatus->execute;
			while (my @rowCheckStatus = $sthCheckStatus->fetchrow_array) {
							system ("iptables -D INPUT -p tcp --syn -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -m connlimit --connlimit-above $conNum -j REJECT --reject-with tcp-reset\n");
							system ("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $process -j ACCEPT\n");
							system ("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -j ACCEPT\n");
			}
			system("iptables -t nat -D PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j DNAT --to-destination ".$proxy_ip.":".$process);
			my $sql_status = "DELETE FROM squid_status WHERE proxy_id=$proxy_id";
			my $sth_status = $dbh->prepare($sql_status);
			$sth_status->execute;
			my $sql_access = "DELETE FROM access_status WHERE proxy_id=$proxy_id";
			my $sth_access = $dbh->prepare($sql_access);
			$sth_access->execute;
		}
	}
	
$sql = "TRUNCATE access_status" ;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sql = "TRUNCATE client_ip" ;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sql = "TRUNCATE squid_logs" ;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sql = "TRUNCATE squid_servers" ;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";
$sql = "TRUNCATE squid_status" ;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";


