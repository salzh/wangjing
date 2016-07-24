#!/usr/bin/perl

use CGI::Simple;
use JSON; # to install, # sudo cpan JSON
require "/usr/local/owsline/lib/default.include.pl";

my $json_engine;

unless ($json_engine) {$json_engine = JSON->new->allow_nonref;}

$cgi = CGI::Simple->new();
print $cgi->header(-charset => "UTF-8");

$channel     = $cgi->param('channel') || reply_error("channel is null");
$roomid		 = $cgi->param('roomid')  || reply_error("roomid is null");


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

