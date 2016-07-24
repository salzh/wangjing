use strict;
use warnings;
use Asterisk::Manager;
my ($user, $secret, $host, $port) = ('manager', 'manager', '127.0.0.1', 50380);
my $ami  = new Asterisk::Manager;


$ami->user($user);
$ami->secret($secret);
$ami->host($host);
$ami->port($port);

$ami->connect || die "fail to login manager";
warn "Success Connect to CCCenter manager: " . $user . "\n";

my $calls = shift || 1;
my $did   = shift || 5856270004;
for (1..$calls) {
	my $callerid = sprintf("%10d", 10000000000+int(rand 9999999999));
	$ami->sendcommand(Action => 'Originate', Channel => "SIP/127.0.0.1:5060/$did",
						  Async => 1,  Timeout => 25000,
						  #Variable => "DETAILID=$row->{id}|DIALEDNUMBER=$dialednumber|workid=$workid",
						  Application => 'echo', Data => '', CallerID => "$callerid <$callerid>", 1);
}
