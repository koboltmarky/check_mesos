#!/usr/bin/perl
use strict;
use LWP::UserAgent;
use Getopt::Long qw(:config no_ignore_case);
use Data::Dumper;
use JSON;
use lib "/usr/lib/nagios/plugins" ;
use IO::Socket::INET;
use utils qw(%ERRORS &print_revision);

#define constants
use constant STATURL=> "/metrics/snapshot";

#define variables
my $mesosMasterIP  = "";
my $mesosMasterPort = "5050";
my $help = 0;
my @zkMasterArray = ();
my $zkPort = 2181;
my $zkLeader  = "";
my $check ="cpus";
my $critical_treshold=0.9;
my $warning_treshold=0.8;

my $result = GetOptions (
 						"help|?" 	=> \$help,
 						"V"     	=> \my $version,
 						"c=f"     => \$critical_treshold,
 						"w=f"     => \$warning_treshold,
 						"H=s{2}" 	=> \@zkMasterArray, 
						"p=s" 		=> \$mesosMasterPort,
						"C=s"			=> \$check, 
			      );

if ($version) {
	print_revision($0,'0.1.0'); 
	exit $ERRORS{'OK'};
}

if ($help) {
 print "Usage is: $0 -H mesosMasterIP1 mesosMasterIP2 -p mesosMasterPort -w warning_treshold -c critical_treshold -C valueToCheck -V (show version) -h (help)";
 exit;
}

main();

sub main {
	my $t1;
	$t1 = getMesosMaster();
	if (!$t1) {
  	print "CRITICAL.Can't get master server. \n";
  	exit $ERRORS{"CRITICAL"};
  }
  check_mesos($t1,$check);
	exit;
}

sub getMesosMaster {
	my $data = "";
	foreach my $zkMaster (@zkMasterArray) {
  	my $statusUrl = "http://".$zkMaster.":".$mesosMasterPort.STATURL;
		my $req = new HTTP::Request 'GET' => $statusUrl;
    my $ua = LWP::UserAgent->new;
	  $ua->timeout(10);
	  my $response = $ua->request($req);
    if ($response->is_success) {
			eval {
		 		$data=decode_json($response->content);
	  		if ($data->{'master/elected'} eq "1") {
	  			$mesosMasterIP=$zkMaster;
					last;
	  		};	
	  	};
	  	
			if ($@) {
	  		warn $@;
	  		print DUMPER $data;
	  	}
  	}
	}
  return $data;
}

# function to check percent values from mesos
# master status page 
#
sub check_mesos {
 	my ($data,$check) = @_;
 	if ($data->{'master/'.$check.'_percent'} < $warning_treshold && $data->{'master/'.$check.'_percent'} < $critical_treshold) {
  	print "OK. $check capacity is good. Capacity: ".$data->{'master/'.$check.'_percent'}."|$check=".$data->{'master/'.$check.'_percent'}."\%;$warning_treshold;$critical_treshold; \n";
   	exit $ERRORS{"OK"}; 
 	}
 	elsif ($data->{'master/'.$check.'_percent'} >= $critical_treshold) {
   	print "CRITICAL. $check capacity is critical. Capacity: ".$data->{'master/'.$check.'_percent'}." \n";
   	exit $ERRORS{"CRITICAL"};
 	}
 	elsif ($data->{'master/'.$check.'_percent'} >= $warning_treshold && $data->{'master/'.$check.'_percent'} < $critical_treshold) {
   	print "WARNING. $check capacity is warning. Capacity: ".$data->{'master/'.$check.'_percent'}."| \n";
   	exit $ERRORS{"WARNING"};
 	}
 	else {
   	print "UNKNOWN. $check capacity is unknown. \n";
	}
}
