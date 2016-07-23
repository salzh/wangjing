#!/usr/bin/perl

use CGI::Simple;
use JSON; # to install, # sudo cpan JSON
require "/usr/local/owsline/lib/default.include.pl";

my $json_engine;

unless ($json_engine) {$json_engine = JSON->new->allow_nonref;}

$cgi = CGI::Simple->new();
print $cgi->header(-charset => "UTF-8");

$id     = $cgi->param('p1') || reply_error("parameter 1: id is null");
$phone1 = $cgi->param('p2') || reply_error("parameter 2: phone1 is null");;
$phone2 = $cgi->param('p3') || reply_error("parameter 3: phone2 is null");;
$minutes = $cgi->param('p4') || reply_error("parameter 4: minutes is null");;

$msg = &asterisk_manager_command(Action => 'Originate', Channel => "Local/$phone1\@loveoutbound2/n", Variable => "id=$id,phone2=$phone2,minutes=$minutes", Context => 'loveincoming2', Exten => 'phone1', Priority => 1, Callerid => '9499995902 <9499995902>');

print(&build_reply({status => 0, message => $msg->{Respone}}));

exit 0;


sub reply_error (){
	print build_reply({status => 0, message => shift});

	exit 0;
}

sub build_reply (){
	my $arg    = shift || {};
	my $hash   = {};
	
	$hash->{status} = $arg->{status} ||0;
	$hash->{message} = $arg->{message} || '';
	
	while (my ($k, $v) = each %$arg) {
		next if !$k || $k eq 'status' || $k eq 'message';
		$hash->{$k} = defined $v ? $v : '';
		#$retstr .= "<$k>" . (defined $v ? $v : '') . "</$k>";
	}

	#$retstr   .= "</response>";

	return $json_engine->encode($hash);
}

