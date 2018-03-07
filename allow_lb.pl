#!/usr/bin/perl -w
use strict;
use DBI;
use DateTime;
use Switch;

my $db;
my $user;
my $pass;
my $instance;

sub read_db_connect_param
{
        open(FILE, "db_connect.txt") or die "Error: no db_connect.txt file found.";
        $db = <FILE>;
        $user = <FILE>;
        $pass = <FILE>;
        $instance = <FILE>;

        chomp($db);
        chomp($user);
        chomp($pass);
        chomp($instance);
}

sub do_log {
        my $message      = shift;
        my $time = localtime();
        return print "$time: allow_lb.pl: $message\n";
}

read_db_connect_param();

do_log "Initializing";
my $dbh = DBI->connect($db,$user,$pass) or die "[".localtime()."] Connection Error: $DBI::errstr\n";
my $lbsql = "SELECT ip FROM mod_proxymngbackend_instances;";
do_log "Iniatializing using : $lbsql";
my $sth2 = $dbh->prepare($lbsql);
$sth2->execute;

while (my @row = $sth2->fetchrow_array) {
	my $cmd = "iptables -t filter -I LB -p tcp -s $row[0] --dport 3128 -j ACCEPT";
        do_log $cmd;
	system($cmd);
}
$sth2->finish();
