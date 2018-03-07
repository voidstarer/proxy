#!/usr/bin/perl -w
use DBI;
use DateTime;
use Time::Piece::MySQL;
use IO::Interface::Simple;
use Data::Validate::IP qw(is_ipv4);
use warnings;
use Switch;

# MySQL Connection
$dbh = DBI->connect('dbi:mysql:squid','squid','testing')
or die "Connection Error: $DBI::errstr\n";

# Funtions
sub checkProxyExist{
	$sqlTemp = "SELECT * FROM squid_status WHERE proxy_id=".$_[0];
	if ($dbh->do($sqlTemp) == 0){
			return "false";
	}else{
			return "true";
	};
}
sub operation{
	$sqlTemp = "UPDATE squid_servers SET operation=0 WHERE id=".$_[0];
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;		
}

sub ServerStatus{
	$sqlTemp = "UPDATE squid_status SET status='$_[1]' WHERE proxy_id=$_[0]";
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
}

sub ProxyRun{
	$sqlTemp = "SELECT status FROM squid_status WHERE proxy_id=$_[0]";
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
	@rowTemp = $sthTemp->fetchrow_array;
	return $rowTemp[1];
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
	$sthTemp = $dbh->prepare($sqlTemp);
	$sthTemp->execute;
}	
	
sub process {
	switch (int(rand(4))) {
		case 0	{ return 3128 }
		case 1	{ return 3128 }
		case 2	{ return 3128 }
		case 3	{ return 3128 }
	}
}

$sql = "SELECT * FROM squid_servers WHERE operation=1 order by id";
$sth = $dbh->prepare($sql);
$sth->execute
or die "SQL Error: $DBI::errstr\n";

$reconfigure = "0";
$mysql_dt = localtime->mysql_datetime;
my @interfaces = IO::Interface::Simple->interfaces;

while (my @row = $sth->fetchrow_array) {

	my ($id,$proxy_id,$proxy_ip,$proxy_port,$connect_num, $action) = @row;	
	my $ipCheck = 0;
	for my $if (@interfaces) {
		if ($if->address eq $proxy_ip){
			$ipCheck = 1;
		}
	}
	
	if (!is_ipv4($proxy_ip)) {
		print "[".localtime()."]"." Proxy Server cannot configurated at ".$proxy_ip.":".$proxy_port.". IP is not being in correct format \n";
		my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server cannot create. IP has wrong format','$mysql_dt','$proxy_ip','$proxy_port','','1')";
		$sth_log = $dbh->prepare($sql_log);
		$sth_log->execute;
		operation($id);
		$action = 0;
	}
	
	if ( $proxy_port eq "" ){
		print "[".localtime()."]"." Proxy Server cannot configurated at ".$proxy_ip.":".$proxy_port.". Port do not have value \n";
		my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Port do not have value','$mysql_dt','$proxy_ip','$proxy_port','','1')";
		$sth_log = $dbh->prepare($sql_log);
		$sth_log->execute;
		operation($id);
		$action = 0;		
	}
	$ipCheck = 1;
	if ($action == 1 && $ipCheck == 1 && is_ipv4($proxy_ip)) {		
			# Create squid instance
			my $sqlExistProxy = "SELECT * FROM squid_status WHERE proxy_ip='$proxy_ip' AND proxy_port='$proxy_port'";
			if ($dbh->do($sqlExistProxy) == 0){
				my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server created','$mysql_dt','$proxy_ip','$proxy_port','','1')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				print "[".localtime()."]"." Proxy Server created at ".$proxy_ip.":".$proxy_port."\n";
				ServerStatus($proxy_id, "Running");
				print "[".localtime()."]"." Proxy Server started at ".$proxy_ip.":".$proxy_port."\n";
				$process = process();
				my $sql_status = "INSERT INTO squid_status(proxy_id, status,proxy_ip,proxy_port,process) VALUES($proxy_id,'Running','$proxy_ip','$proxy_port','$process')";
				$sth_status = $dbh->prepare($sql_status);
				$sth_status->execute;
				#system("iptables -t nat -A PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j REDIRECT --to-port ".$process);
				if ($process != $proxy_port){
					system("iptables -t nat -A PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j DNAT --to-destination ".$proxy_ip.":".$process);
					print "[Command] iptables -t nat -A PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j DNAT --to-destination ".$proxy_ip.":".$process."\n";
				}
				operation($id);
			}else{
				my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server already configurated','$mysql_dt','$proxy_ip','$proxy_port','','1')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				print "[".localtime()."]"." Proxy Server already configurated at ".$proxy_ip.":".$proxy_port."\n";
				operation($id);
			}		
	}elsif($action == 1 && $ipCheck != 1){
			my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server cannot configurated. IP does not exist at system','$mysql_dt','$proxy_ip','$proxy_port','','1')";
			print "[".localtime()."]"." Proxy Server cannot configurate at ".$proxy_ip.":".$proxy_port.", IP Address is not exist at system \n";
			$sth_log = $dbh->prepare($sql_log);
			$sth_log->execute;
			operation($id);
	}

	if ($action == 2){
		# Delete squid instance
		my $sqlExistProxy = "SELECT * FROM squid_status WHERE proxy_ip='$proxy_ip' AND proxy_port='$proxy_port'";
		$sthExistProxy = $dbh->prepare($sqlExistProxy);
		$sthExistProxy->execute;
		my @rowExistProxy = $sthExistProxy->fetchrow_array;
		if ($dbh->do($sqlExistProxy) != 0){
			my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date,proxy_ip,proxy_port,client_ip,category) VALUES($proxy_id,'Proxy Server deleted','$mysql_dt','$proxy_ip','$proxy_port','','2')";
			$sth_log = $dbh->prepare($sql_log);
			$sth_log->execute;
			print "[".localtime()."]"." Proxy Server deleted at ".$proxy_ip.":".$proxy_port."\n";
			$sqlCheckStatus = "SELECT * FROM access_status WHERE proxy_id=$proxy_id";	
			$sthCheckStatus = $dbh->prepare($sqlCheckStatus);
			$sthCheckStatus->execute;
			while (my @rowCheckStatus = $sthCheckStatus->fetchrow_array) {
							system("iptables -D INPUT -p tcp --syn -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -m connlimit --connlimit-above $connect_num -j REJECT --reject-with tcp-reset");
							print "iptables -D INPUT -p tcp --syn -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -m connlimit --connlimit-above $connect_num -j REJECT --reject-with tcp-reset\n";
							if ($rowExistProxy[5] != $rowCheckStatus[4]){
								system("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowExistProxy[5] -j ACCEPT");
							}
							print "[Command] iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowExistProxy[5] -j ACCEPT\n";
							system("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -j ACCEPT");
							print "[Command] iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -j ACCEPT\n";
			}
			#system("iptables -t nat -D PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j REDIRECT --to-port ".$rowExistProxy[5]);
			if ($proxy_port =! $rowExistProxy[5] ){
				system("iptables -t nat -D PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j DNAT --to-destination ".$proxy_ip.":".$rowExistProxy[5]);	
				print "[Command] iptables -t nat -D PREROUTING -d $proxy_ip -p tcp --dport $proxy_port -j DNAT --to-destination ".$proxy_ip.":".$rowExistProxy[5]."\n";
			}
			my $sql_status = "DELETE FROM squid_status WHERE proxy_id=$proxy_id";
			$sth_status = $dbh->prepare($sql_status);
			$sth_status->execute;
			my $sql_access = "DELETE FROM access_status WHERE proxy_id=$proxy_id";
			$sth_access = $dbh->prepare($sql_access);
			$sth_access->execute;
			operation($id);
		}else{
			my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server does not exist','$mysql_dt','$proxy_ip','$proxy_port','','2')";
			$sth_log = $dbh->prepare($sql_log);
			$sth_log->execute;
			print "[".localtime()."]"." Proxy Server does not exist at ".$proxy_ip.":".$proxy_port."\n";
			operation($id);		
		}
	}

	if ($action == 3){
		# Start squid instance
		if (checkProxyExist($proxy_id) eq "true"){
				$sqlCheckStatus = "SELECT * FROM squid_status WHERE proxy_id=$proxy_id AND status='Stopped'";
				if ( $dbh->do($sqlCheckStatus) != 0){
						$sthCheckStatus = $dbh->prepare($sqlCheckStatus);
						$sthCheckStatus->execute;
						@rowCheckStatus = $sthCheckStatus->fetchrow_array;
						#system("iptables -t nat -A PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j REDIRECT --to-port ".$rowCheckStatus[5]);
						if ($rowCheckStatus[4] != $rowCheckStatus[5]){
							system("iptables -t nat -A PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j DNAT --to-destination ".$rowCheckStatus[3].":".$rowCheckStatus[5]);
							print "[Command] iptables -t nat -A PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j DNAT --to-destination ".$rowCheckStatus[3].":".$rowCheckStatus[5]."\n";
						}
						my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server started','$mysql_dt','$proxy_ip','$proxy_port','','3')";
						$sth_log = $dbh->prepare($sql_log);
						$sth_log->execute;
						print "[".localtime()."]"." Proxy Server started at ".$proxy_ip.":".$proxy_port."\n";
						ServerStatus($proxy_id, "Running");
						operation($id);
				}else{
					my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server already run','$mysql_dt','$proxy_ip','$proxy_port','','3')";
					$sth_log = $dbh->prepare($sql_log);
					$sth_log->execute;
					print "[".localtime()."]"." Proxy Server already run at ".$proxy_ip.":".$proxy_port."\n";
					operation($id);
				}
			
		}else{
				my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server cannot start configuration files are missing','$mysql_dt','$proxy_ip','$proxy_port','','3')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"."Proxy Server cannot start configuration files are missing at ".$proxy_ip.":".$proxy_port."\n";
		}
	}
	if ($action == 4){
		# Stop squid instance
		if (checkProxyExist($proxy_id) eq "true"){
				$sqlCheckStatus = "SELECT * FROM squid_status WHERE proxy_id=$proxy_id AND status='Running'";
				if ( $dbh->do($sqlCheckStatus) != 0){
						$sthCheckStatus = $dbh->prepare($sqlCheckStatus);
						$sthCheckStatus->execute;
						@rowCheckStatus = $sthCheckStatus->fetchrow_array;
						#system("iptables -t nat -D PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j REDIRECT --to-port ".$rowCheckStatus[5]);
						if ($rowCheckStatus[4] != $rowCheckStatus[5]){
							system("iptables -t nat -D PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j DNAT --to-destination ".$rowCheckStatus[3].":".$rowCheckStatus[5]);
							print "[Command] iptables -t nat -D PREROUTING -d ".$rowCheckStatus[3]." -p tcp --dport ".$rowCheckStatus[4]." -j DNAT --to-destination ".$rowCheckStatus[3].":".$rowCheckStatus[5]."\n";
						}
						my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server stopped','$mysql_dt','$proxy_ip','$proxy_port','','4')";
						$sth_log = $dbh->prepare($sql_log);
						$sth_log->execute;
						ServerStatus($proxy_id, "Stopped");
						print "[".localtime()."]"." Proxy Server stopped at ".$proxy_ip.":".$proxy_port."\n";
						ClientStatus($proxy_id, 0);
						operation($id);
				}else{
						my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server already stopped','$mysql_dt','$proxy_ip','$proxy_port','','4')";
						$sth_log = $dbh->prepare($sql_log);
						$sth_log->execute;
						print "[".localtime()."]"." Proxy Server already stopped at ".$proxy_ip.":".$proxy_port."\n";
						operation($id);
				}
			
		}else{
				my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server cannot stop configuration files are missing','$mysql_dt','$proxy_ip','$proxy_port','','4')";
				$sth_log = $dbh->prepare($sql_log);
				$sth_log->execute;
				operation($id);
				print "[".localtime()."]"." Proxy Server cannot stop configuration files are missing at ".$proxy_ip.":".$proxy_port."\n";
			}
		}
		
		if ($action == 5) {
			# Reset proxy Server
			my $sqlExistProxy = "SELECT * FROM squid_status WHERE proxy_ip='$proxy_ip' AND proxy_port='$proxy_port'";
			$sthExistProxy = $dbh->prepare($sqlExistProxy);
			$sthExistProxy->execute;
			my @rowExistProxy = $sthExistProxy->fetchrow_array;
			$sqlCheckStatus = "SELECT * FROM access_status WHERE proxy_id=$proxy_id";	
			$sthCheckStatus = $dbh->prepare($sqlCheckStatus);
			$sthCheckStatus->execute;
			while (my @rowCheckStatus = $sthCheckStatus->fetchrow_array) {
							system ("iptables -D INPUT -p tcp --syn -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -m connlimit --connlimit-above $connect_num -j REJECT --reject-with tcp-reset\n");
							print "[Command] iptables -D INPUT -p tcp --syn -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -m connlimit --connlimit-above $connect_num -j REJECT --reject-with tcp-reset\n";
							system ("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowExistProxy[5] -j ACCEPT\n");
							print "[Command] iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowExistProxy[5] -j ACCEPT\n";
							system ("iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -j ACCEPT\n");
							print "[Command] iptables -D INPUT -p tcp -s $rowCheckStatus[2] -d $rowCheckStatus[3] --dport $rowCheckStatus[4] -j ACCEPT\n";
							system "[".localtime()."]"." Connection $rowCheckStatus[2] reseted at proxy ".$proxy_ip.":".$proxy_port."\n";
			}
			my $sqlDel = "DELETE FROM access_status WHERE proxy_id=$proxy_id";
			$sthDel = $dbh->prepare($sqlDel);
			$sthDel->execute;
			my $sql_log = "INSERT INTO squid_logs(proxy_id, log, date, proxy_ip, proxy_port, client_ip, category) VALUES($proxy_id,'Proxy Server reset connections','$mysql_dt','$proxy_ip','$proxy_port','','5')";
			$sth_log = $dbh->prepare($sql_log);
			$sth_log->execute;
			operation($id);
			print "[".localtime()."]"." Connections reset completed at proxy ".$proxy_ip.":".$proxy_port."\n";
		}
		
} 

if ($reconfigure == 1){
	system("squid -k reconfigure -f /opt/squid/config/squid.conf");
	print "[".localtime()."]"." Proxy Server reconfigured \n";
	if ( $? == -1 ){
  		#print "command failed: $!\n";
	}
	else{
  		#printf "command exited with value %d", $? >> 8;
	}
}


