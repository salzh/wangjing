#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
use Switch;
use Data::Dumper;
use DBI;
use Time::Local;
use Math::Round qw(:all);
use Net::AMQP::RabbitMQ;
require "/salzh/backend/outbound/lib/include.pl";

#======================================================


#======================================================
# config
#======================================================
$conference_host 	= $host_name;
$version 			= "1.0.2";
$debug 				= 0;
$fork 				= 0;
$file_pid 			= "/var/run/app_konference.pid";
$file_log 			= "/usr/local/radio/asterisk/log/app_konference.log";
$file_log_bkp 		= "/usr/local/radio/asterisk/log/app_konference.log.bkp";
$host 				= "127.0.0.1";
$port 				= 5038;
$user 				= "wangjing";
$secret 			= "wangjing"; 
$EOL 				= "\015\012";
$BLANK 				= $EOL x 2;
%dtmf_buffer 		= ();
%automute_buffer	= ();
%poll_buffer		= ();
%buffer 			= ();
#======================================================



#======================================================
# arguments
#======================================================
$arguments = join(" ",@ARGV);
$arguments = " \L$arguments ";
if (index($arguments," version ") ne -1) {
	print $version . "\n";
	exit;
}
if (index($arguments," log ") ne -1) {
	$debug = 1;
}
if (index($arguments," logverbose ") ne -1) {
	$debug = 1;
	$|=1;
}
if (index($arguments," daemon ") ne -1) {
	$fork = 1;
	$|=1;
}
if (index($arguments," restart ") ne -1) {
	open FILE, "$file_pid " or die $!;
	my @lines = <FILE>;
	foreach(@lines) {
		`kill -9 $_` 
	}
	close(FILE);
	unlink("$file_pid");
}
#======================================================




#======================================================
# fork
#======================================================
if ($fork == 1) {
	chdir '/'                 or die "Can't chdir to /: $!";
	#umask 0;
	open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
	open STDOUT, ">> $file_log" or die "Can't write to $file_log: $!";
	open STDERR, ">> $file_log" or die "Can't write to $file_log: $!";
	defined(my $pid = fork)   or die "Can't fork: $!";
	exit if $pid;
	setsid                    or die "Can't start a new session: $!";
	$pid = $$;
	open FILE, ">", "$file_pid";
	print FILE $pid;
	close(FILE);
}
$t = getTime();
if (index($arguments," restart ") ne -1) {
	print STDERR "$t STATUS: Listener restarted\n";
}
#======================================================

my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");


#======================================================
# main loop
#======================================================
my @commands;
reconnect:
$remote = IO::Socket::INET->new(
    Proto => 'tcp',
    PeerAddr=> $host,
    PeerPort=> $port,
    Reuse   => 1
) or die goto reconnect;
$t = getTime();
print STDERR "$t STATUS: Connected\n";
$remote->autoflush(1);
$logres = login_cmd("Action: Login${EOL}Username: $user${EOL}Secret: $secret${BLANK}");
$eventcount = 0;
%Channel_Spool = ();
while (<$remote>) {
	$_ =~ s/\r\n//g;
	$_ = trim($_);
	if ($_ eq "") {
		if ($finalline =~ /Event/) {
			# get regular event data
			$finalline = ltrim($finalline);
			#warn $finalline;
			@raw_data = split(/;;/, $finalline);			
			%event = ();
			$t = getTime();
			foreach(@raw_data) {
				@l = split(/\: /,$_);
				$event{$l[0]} = $l[1];
			}
			# expand zenofon extra data at "type" field
			($tmp1,$tmp2,$tmp3,$tmp4) = split(/\|/,$event{Type});
			$event{ZenofonBillingID} = &clean_int($tmp1);
			# call action
			switch ($event{Event}) {
				#case "ConferenceJoin"	{ ConferenceJoin (%event); }
				#case "ConferenceDTMF"	{ ConferenceDTMF (%event); }
				#case "ConferenceLeave"	{ ConferenceLeave(%event); }
				case "Dial"				{ Dial(%event); }
				case "Newchannel"		{ Newchannel(%event); }
				case "Hangup"			{ Hangup(%event); }
			}
			$eventcount++;
		} 
		$finalline="";
	}
	if ($_ ne "") {
		$line = $_;
		if ($finalline eq "") {
			$finalline = $line;
		} else {
			$finalline .= ";;" . $line;
		}
	}
}
$t = getTime();
print STDERR "$t STATUS: Connection Died\n";
goto reconnect;
#======================================================


#======================================================
# poll actions
#======================================================
sub Dial() {
	local(%event) = @_;
	if ($event{SubEvent} eq 'Begin') {
		($name = $event{CallerIDName}) =~ s/ \- .+$//g;
		$number = $event{CallerIDNum};
		$dest	= $event{Dialstring};
		if ($event{Channel} =~ /;2$/) {
			($dc = $event{Channel}) =~ s/;2$//;
			$cname = $Channel_Spool{$dc}{CallerName};
			&log_debug("Set CallerName " . $dc . "=" . $cname . "!\n");
			$dnid = $Channel_Spool{$dc}{dnid};
			&log_debug("Set dnid " . $dc . "=" . $dnid . "!\n");
			$fromuniqueid = $Channel_Spool{$dc}{FromUniqueID};
			&log_debug("Set fromuniqueid " . $dc . "=" . $fromuniqueid . "!\n");
		} else {
			($dc = $event{Destination}) =~ s/;1$//;
			$Channel_Spool{$dc}{CallerName}  = $Channel_Spool{$event{Channel}}{CallerIDName};
			&log_debug("Get CallerName " . $dc . "=" . $Channel_Spool{$dc}{CallerName} . "!\n");
			$Channel_Spool{$dc}{dnid}  = $Channel_Spool{$event{Channel}}{Exten};
			&log_debug("Get dnid " . $dc . "=" . $Channel_Spool{$dc}{dnid} . "!\n");
			
			$Channel_Spool{$dc}{FromUniqueID} = $Channel_Spool{$event{Channel}}{UniqueID};
			&log_debug("Get FromUniqueID " . $dc . "=" . $Channel_Spool{$dc}{FromUniqueID} . "!\n");
		}
		
		if ($dest =~ /^\d+$/){
			%hash = ('caller_id_name' => $name, 'cname' => $cname, 'caller_id_number' => $number, 'destination' => $dest, 'callday' => &date('d'), 'calltime' => &date('t'), 'channel' => $event{Channel}, 'dnid' => $dnid, 'recording' => "/call_recordings/monitor/$fromuniqueid.WAV");
			$mq->publish(1, "incoming", &Hash2Json(%hash));
			&log_debug("Send Event: " . &Hash2Json(%hash));
		}
		

	} elsif ($event{SubEvent} eq 'End') {
	}
}

sub Newchannel() {
	local(%event) = @_;
	$Channel_Spool{$event{Channel}}{CallerIDName} = $event{CallerIDName};
	&log_debug("Get CallerIDName " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{CallerIDName} . "!\n");
	$Channel_Spool{$event{Channel}}{Exten} = $event{Exten};
	&log_debug("Get Exten " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{Exten} . "!\n");
	
	$Channel_Spool{$event{Channel}}{UniqueID} = $event{Uniqueid};
	&log_debug("Get UniqueID " . $event{Channel} . '=' . $Channel_Spool{$event{Channel}}{UniqueID} . "!\n");
}

sub Hangup() {
	local(%event) = @_;
	delete $Channel_Spool{$event{Channel}};
	&log_debug("Delete " . $event{Channel} . "!\n");
}


sub log_debug() {
	$msg = shift;
	$t = getTime();
	print STDERR "$t $msg\n";
}

#======================================================
# john library
#======================================================
sub command {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
       return $buf; 
}
sub getTime {
	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$year = 1900 + $yearOffset;
	if ($hour < 10) {
		$hour = "0$hour";
	}
	if ($minute < 10) {
		$minute = "0$minute";
	}
	if ($second < 10) {
		$second = "0$second";
	}
	$theTime = "[$months[$month] $dayOfMonth $hour:$minute:$second]";
	return $theTime; 
}

sub date {
	$mode = shift;
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	
	if ($mode eq 't') {
		return sprintf("%02d:%02d:%02d", $hour, $minute, $second);
	} elsif ($mode eq 'd') {
		return sprintf("%d/%d/%d", $month+1, $dayOfMonth, $yearOffset+1900);
	}
}

sub login_cmd {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
        return $buf;
}
sub DELETE_trim($) {                                   
        my $string = shift;                     
        $string =~ s/^\s+//;                    
        $string =~ s/\s+$//;            
        return $string;                         
}                                               
sub ltrim($)                             
{                                
        my $string = shift;
        $string =~ s/^\s+//;
        return $string;
}       
sub rtrim($)
{               
        my $string = shift;
        $string =~ s/\s+$//;
        return $string;
}
sub asterisk_debug_print(){
	local($msg) = @_;
	print STDERR "$msg \n";
	
}
#======================================================
 
