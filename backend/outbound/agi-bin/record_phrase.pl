#!/usr/bin/perl
#======================================================
# start script 
#======================================================
use Asterisk::AGI;
use File::Copy;
$AGI = new Asterisk::AGI;
require "/usr/local/owsline/lib/default.include.pl";
%call_data  = ();
%call_data = $AGI->ReadParse();
foreach(@ARGV){($n,$v)=split(/\=/,$_); $call_data{"arg_$n"} = $v}
#--------------------------
# configuration start
#--------------------------
$call_data{system_host}  		= $host_name;
$call_data{system_agi}  		= "record_phrase.pl";
#--------------------------
# configuration stop
#--------------------------
$call_data{system_pid}  		= &clean_int($$);
$call_data{call_did} 			= &clean_int($call_data{dnid}) ;
$call_data{call_did} 			= ($call_data{call_did} eq "") ? &clean_int($call_data{extension}) : $call_data{call_did} ;
$call_data{call_did} 			= (length($call_data{call_did}) eq 10) ? "1".$call_data{call_did} : $call_data{call_did};
$call_data{call_ani} 			= &clean_int($call_data{callerid});
$call_data{call_ani} 			= (length($call_data{call_ani}) eq 10) ? "1".$call_data{call_ani} : $call_data{call_ani};
$call_data{call_dst}			= "";
$call_data{call_uniqueid}		= &clean_str($call_data{uniqueid},"-.");
$call_data{call_channel}		= &clean_str($call_data{channel},"-./@;");

if  ($call_data{call_uniqueid} eq "") {my @mychars=('A'..'Z','a'..'z','0'..'9');$tmp = "";foreach (1..10) {$tmp .= $mychars[rand @mychars];}$call_data{call_uniqueid} = $call_data{system_host} .".". time .".". $tmp;}
$asterisk_debug_switch_screen 	= 1;
$asterisk_debug_switch_file		= 0;
#======================================================



#======================================================
# MAIN LOOP
#======================================================
&asterisk_debug_print("========================================================");
&asterisk_debug_print("$call_data{system_agi}  (START)");
&asterisk_debug_print("========================================================");
&asterisk_debug_print("system_host = $call_data{system_host}");
&asterisk_debug_print("system_agi  = $call_data{system_agi}");
&asterisk_debug_print("system_pid  = $call_data{system_pid}");
&asterisk_debug_print("uniqueid    = $call_data{call_uniqueid}");
&asterisk_debug_print("ani         = $call_data{call_ani}");
&asterisk_debug_print("did         = $call_data{call_did}");
&asterisk_debug_print("channel         = $call_data{call_channel}");

$call_data{call_did} = $call_data{call_did}."          ";
$call_data{channel_id}		= &clean_int(substr($call_data{call_did},4,100));
$call_data{channel_found}	= 0;
$AGI->answer();

PHRASE:
for (1..3) {
    $d = &asterisk_collect_digits('enter_phrase', 3);
    last if ($d || $d eq '0');
}

if (!$d) {
    $AGI->hangup;
    exit 0;
}

$phrase = $d;
if ($phrase !~ /^\d{3}$/) {
    goto PHRASE;
}

$is_existed  = 0;

EXISTED:
if (-e "/var/lib/asterisk/sounds/phrase$phrase.wav") {
	&asterisk_play("phrase$phrase");
	$file = "/var/lib/asterisk/sounds/phrase$phrase";
	$is_existed = 1;
	goto CONFIRM;
} else {
	$is_existed = 0;
}

RECORD:
$file = "/tmp/" . time;
#&asterisk_play('beep');
$AGI->record_file($file, 'wav', '01234567890*#', -1, 0, 'BEEP', 5);

$is_existed = 0;

CONFIRM:
if ($is_existed) {
	$recording_options_file = 'recording_options_no_save';
} else {
	$recording_options_file = 'recording_options';
}
for (1..3) {
    $d = &asterisk_collect_digits($recording_options_file, 1);
	&asterisk_debug_print("d:$d");

    last if $d && ($d eq '1'  || $d eq '2' || $d eq '3' || $d eq '*');
}


unless ($d && ($d eq '1'  || $d eq '2' || $d eq '3'|| $d eq '*')) {
    $AGI->hangup;
    exit 0;  
}

if ($d eq '1' && !$is_existed) {
    move ("$file.wav", "/var/lib/asterisk/sounds/phrase$phrase.wav");
    &asterisk_play('phrase');
    &asterisk_play_digits($phrase);
    &asterisk_play('updated');
    
    goto PHRASE;
} elsif ($d eq '2') {
    &asterisk_play($file);
    goto CONFIRM;
} elsif ($d eq '3') {
    goto RECORD
} elsif ($d eq '*') {
	goto PHRASE;
} else {
    &asterisk_play('error');
    $AGI->hangup;
    exit 0;
}


sub asterisk_debug_print(){
	my ($l) = @_;
	if ($asterisk_debug_switch_screen 	eq 1) { $AGI->verbose(&clean_str($l,"\\/()-_+=:,[]><#*;"),1);	}
	#if ($asterisk_debug_switch_file 	eq 1) { print ASTERISK_DEBUG_FILEHANDLER time."|$l\n";		}
}
sub asterisk_dial(){
	my ($v1,$v2,$v3) = @_;
	return $AGI->exec('Dial', "$v1,$v2,$v3");
}
sub asterisk_hangup(){
	my ($v1,$v2,$v3) = @_;
	$AGI->hangup();
}
sub asterisk_play(){
	my ($audio,$stop_digits) =@_;
	my ($answer,$tmp,$tmp1,$tmp2);
	#&asterisk_debug_print("ASTERISK PLAY ($audio) ($stop_digits)");
	$tmp = $AGI->stream_file($audio,$stop_digits);
	$tmp1 = chr($tmp);
	#&asterisk_debug_print("ASTERISK PLAY answer ($tmp) ($tmp1)");
	return &clean_str($tmp,"#");
}
sub asterisk_record(){
	my ($file,$extension) =@_;
	return $AGI->record_file($file,$extension,1234,300);
}
sub asterisk_talk(){
	my ($msg) =@_;
	return $AGI->exec('Festival', '"'.$msg.'"');
}
sub asterisk_collect_digits(){
	local($prompts_raw,$digits_limit)=@_;
	#local(@prompts,$prompts_qtd,$prompt,$play,$digits,$in_loop,$digits_code,$loop_count);
	$digits_limit++;
	$digits_limit--;
	$digits_limit = ($digits_limit<1) ? 100 : $digits_limit;
	$digits_limit = ($digits_limit>100) ? 100 : $digits_limit;
	my @prompts		= split(/\,/,$prompts_raw);
	my $prompts_qtd = @prompts;
	my $prompt		= "";
	my $play 		= ($prompts_qtd>0) ? 1 : 0;
	my $digits 		= "";
	my $in_loop 	= 1;
    my $digit_code 	= "";
    my $loop_count	= 0;
	while ($in_loop eq 1) {
		$loop_count++;
		if ($loop_count > 100) {
			$in_loop = 0;
		}
		if ($play eq 1) {
			$play = 0;
			foreach $prompt (@prompts) {
				$digit_code = $AGI->stream_file($prompt,"1234567890*#");
				if ($digit_code ne 0) {last}
			}
			if ($digit_code eq 0) {
				$digit_code = $AGI->wait_for_digit('5000');
			}
		} else {
			$digit_code = $AGI->wait_for_digit('5000');
		}
		
		&asterisk_debug_print("digit_code:$digit_code");

		my $digit = chr($digit_code);
		$digit = '*' if $digit_code == 42;
		if ($digit eq "#") {
			$in_loop = 0;
			if ($digits eq "") {$digits = "#"}
		} elsif ($digit_code eq 0) {
			$in_loop = 0;
		} else {
			$digits .= $digit;
		}
		if (length($digits) >= $digits_limit) {
			$in_loop = 0;
		}
	}
	return &clean_str($digits,"*#");
}
sub asterisk_collect_digit(){
	local($prompt,$flags)=@_;
	local($tmp,$digit,$digit_code,$tmp);
	$digit = "";
	if ($prompt ne "") {
		$digit_code = $AGI->stream_file($prompt,"$flags");
		$digit = chr($digit_code);
	}
	if ( ($digit_code eq 0) && (index("\L,$flags,",",no-wait,") eq -1) ) { 
		$tmp = 5000;
		$tmp = (index("\L,$flags,",",wait1sec,") ne -1) ? 1000 : $tmp;
		$tmp = (index("\L,$flags,",",wait2sec,") ne -1) ? 2000 : $tmp;
		$digit_code = $AGI->wait_for_digit($tmp);
		$digit = chr($digit_code);
	}
	return &clean_str($digit,"*#");
}
sub asterisk_play_digits(){
	my ($msg) =@_;
	return $AGI->say_digits($msg);
}
sub asterisk_play_number(){
	my ($msg) =@_;
	return $AGI->say_number($msg);
}
sub asterisk_status() {
	return $AGI->exec('CHANNEL STATUS', '"'.$msg.'"');
}
sub asterisk_status_is_active() {
	local($tmp);
	$tmp = $AGI->stream_file("silence");
	return ($tmp eq 0) ? 1 : 0;
}
sub asterisk_play_dial_number();
sub asterisk_count_active_ani() {
	local($ani_to_search) = @_;
	local($ani_count,$tmp,%ids,$id,$peername,$callid);
	$ani_count = 0;
	$ani_to_search = substr($ani_to_search,1,1000);
	foreach (&asterisk_run_command("sip show channels")) {
		if(index($_,".") eq -1) {next}
		if(index($_,"$ani_to_search") eq -1) {next}
		$tmp=substr($_,29,11);
		$ids{$tmp}++;
	}
	foreach $id (sort keys %ids){
		$peername = "";
		$callid = "";
		foreach (&asterisk_run_command("sip show channel $id")) {
			if (index($_,"Peername:") ne -1){
				$peername = substr($_,25,1000);
			}
			if (index($_,"Caller-ID:") ne -1){
				$callid = substr($_,25,1000);
			}
		}
		if (index($peername,"RNK-01") ne -1){
			if (index($callid,"$ani_to_search") ne -1){
				$ani_count++;
			}
		}
	}
	return $ani_count;
}
sub asterisk_run_command(){
	local($cmd) = @_;
	local(@out,@list,$l);
	@list = `asterisk -r -x "$cmd"`;
	foreach $l (@list) {
		chomp($l);
		@out=(@out,$l);
	}
	return @out;
}
sub asterisk_set_variable(){
	($name,$value) = @_;
	$AGI->set_variable($name,$value);
}
sub asterisk_get_variable(){
	($name) = @_;
	return $AGI->get_variable($name);
}

sub disconnect_phone1 () {
	($channel, $id, $p) = @_;
	
	&asterisk_debug_print("disconnect_phone1 channel=$channel, id=$id");
	$response = `curl -k "http://$hardcoded_webservice_host/updateuslove.asp?fn=JTEST&fn2=CALLEND&id=$id&&status=$p"`;

	&asterisk_manager_command(Action => 'Redirect', Channel => "$channel", Context => 'lovehangupphone1', Exten => 's', priority => 1);
}

sub start_daemon_monitor_konference_minutes() {
	($conference, $minutes) = @_;
	
	open W, "> /tmp/$conference-$minutes.konf";
	print W "name: $conference\nduration:$minutes";
	close W;
	
	return;
	#exit 0;
}
#======================================================





