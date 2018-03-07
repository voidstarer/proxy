#!/usr/bin/perl -w
use warnings;
use strict;
use DBI;
use DateTime;
use Time::Piece::MySQL;
use Switch;
use Net::Address::IP::Local;
use IO::Interface::Simple;


# MySQL Connection
my $dbh = DBI->connect('dbi:mysql:squid','squid','testing')
or die "[".localtime()."] Connection Error: $DBI::errstr\n";

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $sql = "SELECT * FROM ip_pool";
my $sth = $dbh->prepare($sql);
$sth->execute;
my $file = "/etc/proxy/outgoing.conf";
open(my $fh, '>', $file) or die "Could not open the file '$file' $!";

while (my @row = $sth->fetchrow_array) {
	
	print $fh "acl squid_".$row[0]." myip ".$row[1]."\n";
    print $fh "tcp_outgoing_address ".$row[1]." squid_".$row[0]."\n";
	
}
close $fh;
