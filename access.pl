#!/usr/bin/perl -w
use warnings;
use DBI;
use DateTime;
use Time::Piece::MySQL;

#MySQL Connection
$dbh = DBI->connect('dbi:mysql:squid','squid','testing')
or die "Connection Error: $DBI::errstr\n";

#Functions

sub checkProxyExist{
	$sqlTemp = "SELECT * FROM squid_status WHERE proxy_id=".$_[0];
	if ($dbh->do($sqlTemp) == 0){
			return "false";
	}else{
			return "true";
	};
}
sub operation{
	$sqlTemp = "UPDATE client_ip SET operation=0 WHERE id=".$_[0];
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;		
}

sub ServerStatus{
	$sqlTemp = "UPDATE squid_status SET status='$_[1]' WHERE proxy_id=$_[0]";
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
}

sub showstatus{
	$sqlTemp = "SELECT status FROM squid_status WHERE proxy_id=".$_[0];
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
	@rowTemp = $sthTemp->fetchrow_array;
	return $rowTemp[0];
}

sub ConnectionNum{
	$sqlTemp = "SELECT connect_num FROM squid_servers WHERE proxy_id=".$_[0];
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
	@rowTemp = $sthTemp->fetchrow_array;
	print $rowTemp[1];
}

sub ClientStatus{
	$sqlTemp = "UPDATE access_status SET enabled='$_[1]' WHERE id=$_[0]";
	print $sqlTemp;
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
}

sub process {
	$sqlTemp = "SELECT process FROM squid_status WHERE proxy_id=".$_[0];
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
	@rowTemp = $sthTemp->fetchrow_array;
	return $rowTemp[0];
}	


$sql = "SELECT * FROM client_ip RIGHT JOIN squid_servers ON client_ip.proxy_id=squid_servers.proxy_id WHERE client_ip.operation=1 order by client_ip.id";
# print $sql;
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";

$mysql_dt = localtime->mysql_datetime;

while (my @row = $sth->fetchrow_array) {

		my ($id,$proxy_id,$client_ip, $action,$operation,$idSS,$proxy_idSS,$proxy_ipSS,$proxy_portSS,$conNum) = @row;
		if ($action == 1 and defined $client_ip){
			# Give Access to client 	
			if (checkProxyExist($proxy_id) eq "true"){
				my $sqlCheckStatus = "SELECT * FROM access_status WHERE proxy_id='$proxy_id' AND client_ip='$client_ip' AND proxy_ip='$proxy_ipSS' AND proxy_port='$proxy_portSS'";
				$sthCheckStatus = $dbh->prepare($sqlCheckStatus);
				$sthCheckStatus->execute;
				my @rowCheckStatus = $sthCheckStatus->fetchrow_array;
				if (scalar(@rowCheckStatus) == 0){
						$process = process($proxy_id);
						if ($proxy_portSS != $process){
							system("iptables -I INPUT -p tcp -s $client_ip -d $proxy_ipSS --dport $proxy_portSS -j ACCEPT");
							print "[Command] iptables -I INPUT -p tcp -s $client_ip -d $proxy_ipSS --dport $proxy_portSS -j ACCEPT\n";
						}
						system("iptables -I INPUT -p tcp -s $client_ip -d $proxy_ipSS --dport $process -j ACCEPT");
						print "[Command] iptables -I INPUT -p tcp -s $client_ip -d $proxy_ipSS --dport $process -j ACCEPT\n";
						system("iptables -I INPUT -p tcp --syn -s $client_ip -d $proxy_ipSS --dport $proxy_portSS -m connlimit --connlimit-above $conNum -j REJECT --reject-with tcp-reset");
						print "[Command] iptables -I INPUT -p tcp --syn -s $client_ip -d $proxy_ipSS --dport $proxy_portSS -m connlimit --connlimit-above $conNum -j REJECT --reject-with tcp-reset\n";
						my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Client IP access allowed','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','6')";
						$sth_log = $dbh->prepare($sql_log);
						$sth_log->execute;
						print "[".localtime()."]"." Client IP:$client_ip access allowed at ".$proxy_ipSS.":".$proxy_portSS."\n";
						$sql_log = "INSERT INTO access_status(proxy_id,client_ip,proxy_ip,proxy_port, date) VALUES($proxy_id,'$client_ip','$proxy_ipSS','$proxy_portSS','$mysql_dt')";
						$sth_client_log = $dbh->prepare($sql_log);
						$sth_client_log->execute;					
						operation($id);
				}else{
					my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Client IP access already allowed','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','6')";
					$sth_log = $dbh->prepare($sql_log);
					$sth_log->execute;
					operation($id);
					print "[".localtime()."]"." Client IP:$client_ip access already allowed at ".$proxy_ipSS.":".$proxy_portSS."\n";
				}
			}else{
				$sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES(".$proxy_id.",'Client IP access did not allow because there is not running proxy','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','6')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"." Client IP:$client_ip access did not allow because there is not a running proxy at ".$proxy_ipSS.":".$proxy_portSS."\n";
			}

		}elsif($action == 1 and !defined $client_ip){
				$sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES(".$proxy_id.",'Client IP is null. Cannot give access','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','6')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"." Client IP is null. Cannot give access at Proxy ".$proxy_ipSS.":".$proxy_portSS."\n";		
		
		}elsif($action == 2 && $client_ip ne ""){
			$sqlCheck = "SELECT * FROM access_status LEFT JOIN squid_servers ON access_status.proxy_id=squid_servers.proxy_id WHERE access_status.proxy_id=".$proxy_id." AND access_status.client_ip='".$client_ip."' ";
			$sthCheck = $dbh->prepare($sqlCheck);
			$sthCheck->execute;
			@rowCheck = $sthCheck->fetchrow_array;			
			if (scalar(@rowCheck) != 0){
				$process = process($proxy_id);
				system("iptables -D INPUT -p tcp --syn -s $rowCheck[2] -d $rowCheck[3] --dport $rowCheck[4] -m connlimit --connlimit-above $conNum -j REJECT --reject-with tcp-reset");
				print "[Command] iptables -D INPUT -p tcp --syn -s $rowCheck[2] -d $rowCheck[3] --dport $rowCheck[4] -m connlimit --connlimit-above $conNum -j REJECT --reject-with tcp-reset\n";
				system("iptables -D INPUT -p tcp -s $rowCheck[2] -d $rowCheck[3] --dport $process -j ACCEPT");
				print "[Command] iptables -D INPUT -p tcp -s $rowCheck[2] -d $rowCheck[3] --dport $process -j ACCEPT\n";
				if ($process != $rowCheck[4]){
					system("iptables -D INPUT -p tcp -s $rowCheck[2] -d $rowCheck[3] --dport $rowCheck[4] -j ACCEPT");
					print "[Command] iptables -D INPUT -p tcp -s $rowCheck[2] -d $rowCheck[3] --dport $rowCheck[4] -j ACCEPT\n";
				}
				$sqlremove = "DELETE FROM access_status WHERE proxy_id=".$proxy_id." AND client_ip='".$client_ip."' ";
				$sthremove = $dbh->prepare($sqlremove);
				$sthremove->execute;
				$sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES(".$proxy_id.",'Client IP access removed','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','7')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"." Client IP:$client_ip access removed from $rowCheck[3]:$rowCheck[4]"."\n";				
			}else{
				$sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES(".$proxy_id.",'Client IP access not exist','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','7')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				print "[".localtime()."]"." Client IP:$client_ip access not exist\n";
				operation($id);
			}
		}elsif($action == 2 && $client_ip eq ""){
				$sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES(".$proxy_id.",'Client IP is null. Cannot deny access','$mysql_dt','$proxy_ipSS','$proxy_portSS','$client_ip','6')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"." Client IP is null. Cannot deny access at Proxy ".$proxy_ipSS.":".$proxy_portSS."\n";		
		}
}





# iptables -A INPUT -p tcp -s 83.235.179.173 --dport 3129 -j ACCEPT

