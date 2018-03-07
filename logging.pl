#!/usr/bin/perl -w
use warnings;
use strict;
use DBI;
use DateTime;
use Time::Piece::MySQL;
use Switch;
use Net::Address::IP::Local;
use IO::Interface::Simple;

# Functions

# MySQL Connection
my $dbh = DBI->connect('dbi:mysql:squid','squid','testing')
or die "[".localtime()."] Connection Error: $DBI::errstr\n";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my @interfaces = IO::Interface::Simple->interfaces;


# Main Program

if ($ARGV[0] == 1){
	my $sql = "SELECT * FROM squid_servers WHERE operation=1";
	if ($dbh->do($sql) != 0){
		
			print "[".localtime()."] Event for proxy setup recorded. Running main script to execute the command \n";
			
			my $sth = $dbh->prepare($sql);
			$sth->execute;
			
			while (my @row = $sth->fetchrow_array) {
					
				switch ($row[5]) {
					case 1	{ print "[".localtime()."] Event for creating proxy with IP $row[2] at port $row[3]\n"; }
					case 2	{ print "[".localtime()."] Event for deleting proxy with IP $row[2] at port $row[3]\n"; }
					case 3	{ print "[".localtime()."] Event for starting proxy with IP $row[2] at port $row[3]\n"; }
					case 4	{ print "[".localtime()."] Event for stopping proxy with IP $row[2] at port $row[3]\n"; }
					case 5	{ print "[".localtime()."] Event for reseting proxy with IP $row[2] at port $row[3]\n"; }
				}
			}
	};

}elsif ($ARGV[0] == 2){
		my $sql = "SELECT * FROM client_ip RIGHT JOIN squid_servers ON client_ip.proxy_id=squid_servers.proxy_id WHERE client_ip.operation=1";
		if ($dbh->do($sql) != 0){
		
			print "[".localtime()."] Event for access setup recorded. Running access script to execute the command \n";
			my $sth = $dbh->prepare($sql);
			$sth->execute
			or die "SQL Error: $DBI::errstr\n";
			while (my @row = $sth->fetchrow_array) {
				#print "@row\n";	
				switch ($row[3]) {
					case 1	{ print "[".localtime()."] Event to give access to client with IP $row[2] at proxy $row[7]:$row[8]\n"; }
					case 2	{ print "[".localtime()."] Event to remove access to client with IP $row[2] at proxy $row[7]:$row[8]\n"; }
				}
			}
		}
}else{
	my @stat = `ps aux | grep squid | grep conf |grep root|grep -v grep`;
	if (scalar(@stat) == 0){
		print "[".localtime()."] Server is not running, check your configuration\n";	
	}else{
		my $sql = "SELECT * FROM squid_status";
		my $sqlRun = "SELECT * FROM squid_status WHERE Status='Running'";
		if ($min % 10 == 0){
			print "[".localtime()."] Proxy server is running. Total servers : ".$dbh->do($sql).". Running servers : ".$dbh->do($sqlRun)."\n";
		}
	
		if ($min % 10 == 0){
			my $sql = "SELECT process,COUNT(*) FROM squid_status GROUP BY process";
			my $sth = $dbh->prepare($sql);
			$sth->execute;
			my $balance = "(";
			while (my @row = $sth->fetchrow_array){
					$balance = $balance . $row[1] . ",";
			}
			chop($balance);
			$balance = $balance.")";
			# print "[".localtime()."] Balance of service $balance \n";
		}
		$sql = "SELECT DISTINCT client_ip FROM access_status";
		$sqlRun = "SELECT * FROM access_status";
		if ($min % 50 == 0){
			print "[".localtime()."] Access report. Total users : ".($dbh->do($sql)).". Total connections ".$dbh->do($sqlRun)."\n";
			print "[".localtime()."] Saving firewall settings \n ";
			my $dirname = "/etc/proxy/iptables";
			my $count;
			opendir ( DIR, $dirname ) || die "[".localtime()."]Error in opening dir $dirname\n";
			while( (my $filename = readdir(DIR))){
				$count++;
			}
			closedir(DIR);
			system ("mv /etc/proxy/iptables.save /etc/proxy/iptables/iptables.$count");
			system ("iptables-save > /etc/proxy/iptables.save");
		}

	}
	
}

