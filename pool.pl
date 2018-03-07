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

my $sql_del = "TRUNCATE TABLE ip_pool";
my $sth_del = $dbh->prepare($sql_del);
$sth_del->execute;
$sql_del = "TRUNCATE TABLE ip_pool_temp";
$sth_del =$dbh->prepare($sql_del);
$sth_del->execute;
my $count = 0;
print "[".localtime()."] Refreshing IP pool table from system\n";
for my $if (@interfaces) {
	if (($if ne "lo") and ($if ne "eth0") and ($if ne "eth1") and ($if ne "eth1:1") and ($if ne "eth1:1") and ($if ne "eth1:2") and ($if ne "eth1:3") and ($if ne "eth1:4")){
#			if ((index($if->address,"67.21.32") != -1) or (index($if->address,"67.21.33") != -1)){
				my $sql_ip = "INSERT INTO ip_pool_temp(ip, interface) VALUES('".$if->address."','".$if."')";
				my $sth_ip = $dbh->prepare($sql_ip);
				$sth_ip->execute;
				#print $if->address."\n";
				$count++;
#			}
	}
}
print "[".localtime()."] Added IP in temp pool table : ".$count."\n";
$count = 0;
my $sql_rand = "SELECT * FROM ip_pool_temp ORDER BY RAND()";
my $sth_rand = $dbh->prepare($sql_rand);
$sth_rand->execute
or die "SQL Error: $DBI::errstr\n";

while (my @row_rand = $sth_rand->fetchrow_array) {
	
	my $sql_ip = "INSERT INTO ip_pool(ip, interface) VALUES('".$row_rand[1]."','".$row_rand[2]."')";
	my $sth_ip = $dbh->prepare($sql_ip);
	$sth_ip->execute;
	$count++;
}

print "[".localtime()."] Added IP in pool table (random mode) : ".$count."\n";

	
