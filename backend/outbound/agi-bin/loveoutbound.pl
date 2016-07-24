#!/usr/bin/perl
#======================================================
# start script 
#======================================================
use Asterisk::AGI;
$AGI = new Asterisk::AGI;
require "/usr/local/owsline/lib/default.include.pl";
%call_data  = ();
%call_data = $AGI->ReadParse();
foreach(@ARGV){($n,$v)=split(/\=/,$_); $call_data{"arg_$n"} = $v}
#--------------------------
# configuration start
#--------------------------
$call_data{system_host}  		= $host_name;
$call_data{system_agi}  		= "loveoutbound.pl";
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

if ($call_data{arg_dialstatus} eq 'PHONEHANGUP') {
		$phone2_answertime = $AGI->get_variable('ANSWEREDTIME') || 0;
        $id = $AGI->get_variable("ID");
        if ($id) {
            unless ($phone2_answertime) {
                $response = `curl -k "http://$hardcoded_webservice_host/updateuslove.asp?fn=JTEST&fn2=CALLEND&id=$id&status=1"`;
            }

        } else {
            $phone1channel = $AGI->get_variable('PHONE1_CHANNEL');
            $phone1id	   = $AGI->get_variable('PHONE1_ID');
            unless ($phone2_answertime) {
                disconnect_phone1($phone1channel, $phone1id, '2');
            }
            
        }	
} elsif ($call_data{arg_dialstatus} eq 'PHONE2ANSWER') {
	for (1..5) {
		$enter_code_file = 'phrase103';
        
		$d = &asterisk_collect_digits($enter_code_file, 1);
		last if ($d || $d eq '0');
	}
	
	&asterisk_debug_print("phone2 press $d");
	$phone1channel = $AGI->get_variable('PHONE1_CHANNEL');
	
	$phone1id	   = $AGI->get_variable('PHONE1_ID');
	$minutes	   = $AGI->get_variable("CONFMINUTES");
	
	unless ($d && $d == 2) {
		disconnect_phone1($phone1channel, $phone1id, 'P');
		$AGI->hangup();
		exit 0;
	}
	
	&asterisk_debug_print("phone2 press $d");

	$response = `curl -k "http://$hardcoded_webservice_host/updateuslove.asp?fn=JTEST&fn2=CONNECTIONSTARTED&id=$phone1id"`;
	
	#&asterisk_play('go_ahead');
	
	$conference =  time;
	&asterisk_manager_command(Action => 'SetVar', Channel => $phone1channel, Variable => 'konferencename', Value => $conference);
	&asterisk_manager_command(Action => 'SetVar', Channel => $call_data{call_channel}, Variable => 'konferencename', Value => $conference);
	&asterisk_manager_command(Action => 'SetVar', Channel => $phone1channel, Variable => 'phraseMinutes', Value => "phrase" . (800+$minutes));
	&asterisk_manager_command(Action => 'SetVar', Channel => $call_data{call_channel}, Variable => 'phraseMinutes', Value => "phrase" . (800+$minutes));
    
	&start_daemon_monitor_konference_minutes($conference, $minutes);

	&asterisk_manager_command(Action => 'Redirect', Channel => "$call_data{call_channel}", Extrachannel => $phone1channel,  Context => 'loveconference2', Exten => "99$conference", Priority => 1);
	
	
} elsif ($call_data{arg_dialstatus} eq 'KONFEND') {
	$konferencename = $AGI->get_variable('konferencename');
    $phone1id	   = $AGI->get_variable('PHONE1_ID');
	if ($phone1id) {
		$reponse =  `curl -k "http://$hardcoded_webservice_host/updateuslove.asp?fn=JTEST&fn2=CONNECTIONENDED&id=$phone1id"`;
	}
	if ($konferencename) {
		&asterisk_manager_command('Action' => 'Command', 'command' => "konference end $konferencename");
	}
	

	
	exit 0;
} else {
	$AGI->answer();
	
	
	#($type, $id, $phone2, $minutes)  = split /~/, $response;
    $id     = &asterisk_get_variable('id');
    $phone2 = &asterisk_get_variable('phone2');
    $minutes= &asterisk_get_variable('minutes');
	
	if (!$phone2) {
		disconnect_phone1($call_data{call_channel}, $id);
		$AGI->hangup();
		exit 0;
	}
	
	&asterisk_debug_print("id=$id phone2=$phone2 minutes=$minutes");


	$pid = fork();
	if ($pid < 1) {
		&asterisk_manager_command(Action => 'Originate', Channel => "Local/$phone2\@loveoutbound2/n", Variable => "PHONE1_CHANNEL=$call_data{call_channel},PHONE1_ID=$id,CONFMINUTES=$minutes", Context => 'loveincoming2', Exten => 'phone2', Priority => 1, Callerid => '9499995902 <9499995902>');
		exit 0;
	}
	
	&asterisk_debug_print("originate sent");

	while (1) {
		$hold_file = 'phrase101'; # || 'hold';
        
		&asterisk_play($hold_file);
		sleep 600;
	}
	
}
exit;

#======================================================
# asterisk lib
#======================================================
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
				$digit_code = $AGI->wait_for_digit('3000');
			}
		} else {
			$digit_code = $AGI->wait_for_digit('3000');
		}
		my $digit = chr($digit_code);
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
	return &clean_str($digits,"#");
}
sub asterisk_collect_digit(){
	local($prompt,$flags)=@_;
	local($tmp,$digit,$digit_code,$tmp);
	$digit = "";
	if ($prompt ne "") {
		$digit_code = $AGI->stream_file($prompt,"1234567890*#");
		$digit = chr($digit_code);
	}
	if ( ($digit_code eq 0) && (index("\L,$flags,",",no-wait,") eq -1) ) { 
		$tmp = 5000;
		$tmp = (index("\L,$flags,",",wait1sec,") ne -1) ? 1000 : $tmp;
		$tmp = (index("\L,$flags,",",wait2sec,") ne -1) ? 2000 : $tmp;
		$digit_code = $AGI->wait_for_digit($tmp);
		$digit = chr($digit_code);
	}
	return &clean_str($digit,"#");
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
	$response = `curl -k "http://$hardcoded_webservice_host/updateuslove.asp?fn=JTEST&fn2=CALLEND&id=$id&status=$p"`;

	&asterisk_manager_command(Action => 'Redirect', Channel => "$channel", Context => 'lovehangupphone1_2', Exten => 's', priority => 1);
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





