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
$call_data{system_agi}  		= "app_konference_radio.ask_conference.pl";
#--------------------------
# configuration stop
#--------------------------
$call_data{system_pid}  		= &clean_int($$);
$call_data{call_did} 			= &clean_int($call_data{dnid});
$call_data{call_did} 			= (length($call_data{call_did}) eq 10) ? "1".$call_data{call_did} : $call_data{call_did};
$call_data{call_ani} 			= &clean_int($call_data{callerid});
$call_data{call_ani} 			= (length($call_data{call_ani}) eq 10) ? "1".$call_data{call_ani} : $call_data{call_ani};
$call_data{call_dst}			= "";
$call_data{call_uniqueid}		= &clean_str($call_data{uniqueid},"-.");
if  ($call_data{call_uniqueid} eq "") {my @mychars=('A'..'Z','a'..'z','0'..'9');$tmp = "";foreach (1..10) {$tmp .= $mychars[rand @mychars];}$call_data{call_uniqueid} = $call_data{system_host} .".". time .".". $tmp;}
$asterisk_debug_switch_screen 	= 1;
$asterisk_debug_switch_file		= 0;
#======================================================



#======================================================
# MAIN LOOP
#======================================================
#
#-------------------------------------
# start
#-------------------------------------
&asterisk_debug_print("========================================================");
&asterisk_debug_print("$call_data{system_agi}  (START)");
&asterisk_debug_print("========================================================");
&asterisk_debug_print("system_host=$call_data{system_host}");
&asterisk_debug_print("system_agi=$call_data{system_agi}");
&asterisk_debug_print("system_pid=$call_data{system_pid}");
&asterisk_debug_print("uniqueid=$call_data{call_uniqueid}");
&asterisk_debug_print("ani=$call_data{call_ani}");
&asterisk_debug_print("did=$call_data{call_did}");
$call_data{radio_is_ok} 		= 0;
$call_data{radio_has_errors} 	= 0;
#
#-------------------------------------
# check station DID
#-------------------------------------
&asterisk_debug_print("Search radio station for did=$call_data{call_did}");
$sql = "
SELECT 1,1,r.id,r.title, r.prompt_question_logic, r.prompt_noinput_logic  
from radio_data_did as d, radio_data_station as r 
where r.id=d.radio_data_station_id and d.did='%s' 
order by r.date_last_change desc limit 0,1 
";
$sql = &database_scape_sql($sql,$call_data{call_did});
&asterisk_debug_print("$sql");
%hash = &database_select_as_hash($sql,"flag,id,title,prompt_question_logic,prompt_noinput_logic");
if ($hash{1}{flag} eq 1) {
	# radio found
	$call_data{radio_did_has_station}	= 1;
	$call_data{radio_station_id} 		= $hash{1}{id};
	$call_data{radio_station_title} 	= $hash{1}{title};
	$call_data{prompt_question_logic} 	= $hash{1}{prompt_question_logic};
	$call_data{prompt_noinput_logic} 	= $hash{1}{prompt_noinput_logic};
	&asterisk_debug_print("found radio=$call_data{radio_station_id} $call_data{radio_station_title}");
} else {
	# radio NOT found
	&asterisk_debug_print("no radio found! ");
	$call_data{radio_has_errors} = 1;
}



#
#-------------------------------------
# get client id
#-------------------------------------
&get_client_id_for_this_call();
# this is a helper that search ani/facebook/google and fill this variables:
# $call_data{client_id_is_unknown} = 1 if cannot find client_id
# $call_data{client_id} = client id for this call
# we use this for local API, but better initiate right now, so i already have this values from now on
#


#-------------------------------------
# get station channels
#-------------------------------------
if ($call_data{radio_has_errors} eq 0) {
	#
	# get channels list
	&asterisk_debug_print("get channels for this radio! ");
	$call_data{radio_channels_ext_max_length} 	= 0;
	$call_data{radio_channels_count}			= 0;
	$call_data{radio_has_channels}				= 0;
	$call_data{radio_channels_first_id}			= "";
	$call_data{radio_channels_first_ext}		= "";
	$sql = &database_scape_sql("select id,extension,listen_pin from radio_data_station_channel where enabled=1 and radio_data_station_id='%s' ",$call_data{radio_station_id}); 
	%hash = &database_select_as_hash($sql,"extension,listen_pin");
	foreach $tmp (sort{$hash{$a} <=> $hash{$b}} keys %hash) {
		$call_data{radio_channels_listen_pin}{$tmp} = $hash{$tmp}{listen_pin};
		$call_data{radio_channels_ids2ext}{$tmp} = $hash{$tmp}{extension};
		$call_data{radio_channels_ext2ids}{$hash{$tmp}{extension}} = $tmp;
		$call_data{radio_channels_ext_max_length} = (length($hash{$tmp}{extension}) > $call_data{radio_channels_ext_max_length}) ? length($hash{$tmp}{extension}) : $call_data{radio_channels_ext_max_length};
		$call_data{radio_channels_count}++;
		$call_data{radio_has_channels}	= 1;
		$call_data{radio_channels_first_id} = ($call_data{radio_channels_first_id} eq "") ? $tmp : $call_data{radio_channels_first_id};
		$call_data{radio_channels_first_ext} = ($call_data{radio_channels_first_ext} eq "") ? $hash{$tmp}{extension} : $call_data{radio_channels_first_ext};
		&asterisk_debug_print("Channel found: id=$tmp ext=$hash{$tmp}{extension} count=$call_data{radio_channels_count} max_length=$call_data{radio_channels_ext_max_length} ");
	}
	#
	# get default 
	&asterisk_debug_print("This radio has $call_data{radio_channels_count} channels.");
	if ($call_data{radio_has_channels} ne 1) { &asterisk_debug_print("Error. this radio has no channels"); }
}
# 
#-------------------------------------
# check if we have all ok 
#-------------------------------------
$call_data{radio_is_ok} = (
	($call_data{radio_has_errors} eq 0) &&   
	($call_data{radio_did_has_station} eq 1) &&   
	($call_data{radio_has_channels} eq 1)
	) ? 1 : 0;
# 
#-------------------------------------
# main loop 
#-------------------------------------
if ($call_data{radio_is_ok} ne 1) {
	# 
	#-------------------------------------
	# no radio found
	#-------------------------------------
	&asterisk_debug_print("Radio is not ok to play. Stop call.");
	&asterisk_play("multilevel-pbxbyani-radio-incorrect-exten");
	&hangup_this_call();
} else {
	#
	#-------------------------------------
	# play welcome prompt if loop count = 1
	#-------------------------------------
	$call_data{loop_counter} = clean_int(&asterisk_get_variable("loop_counter"));
	$call_data{loop_counter} = ($call_data{loop_counter} eq "") ? 0 : $call_data{loop_counter};
	$call_data{loop_counter}++;
	&asterisk_set_variable("loop_counter",$call_data{loop_counter});
	&asterisk_debug_print("in this call, loop_counter=$call_data{loop_counter} ");
	if ($call_data{loop_counter} eq 1) {
		&asterisk_debug_print("Its first time. Lets play welcome prompt");
		&radio_prompt_play($call_data{radio_station_id},"welcome");
	}
	#
	#-------------------------------------
	# hangup if loop count > 50
	# we move this logic to dialplan
	#-------------------------------------
	#if ($call_data{loop_counter} > 50) {
	#	&asterisk_debug_print("this call ask to radio more than 50 times. maybe ita a dead call in loop, lets hangup");
	#	&radio_prompt_play($call_data{radio_station_id},"too_much_questions");
	#	&hangup_this_call();
	#}
	#
	#-------------------------------------
	# auto select channel by prompt_question_logic
	#-------------------------------------	
	if ($call_data{prompt_question_logic} eq "promptorquicklast") {
		# if user return too fast, lets remember last channel
		$tmp1 = &get_client_data_at_this_station("last_digits");
		$tmp2 = &get_client_data_at_this_station("last_digits_timestamp");
		if ( (time-$tmp2) < (60*5) ) {
			&asterisk_debug_print("I remember this client. The lest digits he type ($tmp1) was 5 minutes ago. Lets auto-digit to make they life simple");
			%channel_data = &search_channel_by_digits($tmp);
			if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); }
		}
	} elsif ( ($call_data{prompt_question_logic} ne "") && (&clean_int($call_data{prompt_question_logic}) eq $call_data{prompt_question_logic}) ) {
		# We need go to one specific channel
		&asterisk_debug_print("Radio owner decide we need always send people to one specific channel");
		%channel_data = &search_channel_by_channel_id($call_data{prompt_question_logic});
		if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); }
	}
	#
	#-------------------------------------
	# select channel
	#-------------------------------------	
	if ($call_data{radio_channels_count} eq 1) {
		#
		#-------------------------------------
		# only one channel. lets kick direct to this channel
		#-------------------------------------		
		&asterisk_debug_print("We have only one channel ext=$call_data{radio_channels_first_ext}) on this radio. Lets play without ask");
		%channel_data = &search_channel_by_digits($call_data{radio_channels_first_ext});
		if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); }
	} else {
		#
		#-------------------------------------
		# ask for channel
		#-------------------------------------
		&asterisk_debug_print("We have multiple extension on this radio. Lets ask extension with $call_data{radio_channels_ext_max_length} digits");
		foreach (1..20) {
			#
			#-------------------------------------
			# ask digits
			#-------------------------------------
			$call_data{main_loop_count}++;
			&asterisk_debug_print("Ask radio extension (loop '$call_data{main_loop_count}') ");
			$digits 			= &asterisk_collect_digits(&radio_prompt_get_id($call_data{radio_station_id},"extension_question"),$call_data{radio_channels_ext_max_length});
			$channel_id			= "";
			$selected_by_user	= 0;
			#
			#-------------------------------------
			# check digits 
			#-------------------------------------
			&asterisk_debug_print("User digits=($digits) !");
			if ($digits eq "0") {
				#
				#----------------------------
				# User enter 0 as digit. lets play help 
				#----------------------------
				$tmp = radio_prompt_get_id($call_data{radio_station_id},"help");
				if ($tmp ne "") {
					&asterisk_debug_print("User select 0 and we have help prompt. lets play");
					$digits = &asterisk_collect_digits($tmp,1);				
				} else {
					&asterisk_debug_print("User select 0 but we dont have help prompt. lets skip");
				}
			} elsif ($digits ne "") {
				#
				#----------------------------
				# we have digits.. lets try as channel
				#----------------------------
				&asterisk_debug_print("search channel_id by digits");
				%channel_data = &search_channel_by_digits($digits);
				$channel_data{selected_by_user} = 1;
				if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); } else {&asterisk_debug_print("No channel_id found for digits=$digits"); &radio_prompt_play($call_data{radio_station_id},"extension_error"); }
			} else {
				#
				#----------------------------
				# we have NO digits.. lets check prompt_noinput_logic
				#----------------------------
				if ($call_data{prompt_noinput_logic} eq "last") {
					#
					#-------------------------------------
					# remember last selection
					#-------------------------------------
					$digits = &get_client_data_at_this_station("last_digits");
					&asterisk_debug_print("remember last digits=$digits by prompt_noinput_logic=last");
					%channel_data = &search_channel_by_digits($digits);
					if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); } else {&asterisk_debug_print("No channel_id found for digits=$digits"); &radio_prompt_play($call_data{radio_station_id},"extension_error"); }
				} elsif ($call_data{prompt_noinput_logic} eq "next") {
					#
					#-------------------------------------
					# remember last selection and go next
					#-------------------------------------
					$digits = &get_client_data_at_this_station("last_digits");
					@array = (sort{$a <=> $b} keys %{$call_data{radio_channels_ext2ids}});
					@array = (@array,@array);
					$tmp1 = @array;
					foreach $tmp2 (0..$tmp2) {
						if ( (@array)[$tmp2] eq $digits ) {
							$digits = (@array)[$tmp2+1];
							last;
						}
					}
					&asterisk_debug_print("remember last digits=$digits by prompt_noinput_logic=next");
					%channel_data = &search_channel_by_digits($digits);
					if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); } else {&asterisk_debug_print("No channel_id found for digits=$digits"); &radio_prompt_play($call_data{radio_station_id},"extension_error"); }
				} elsif ( ($call_data{prompt_question_logic} ne "") && (&clean_int($call_data{prompt_question_logic}) eq $call_data{prompt_question_logic}) ) {
					#
					#-------------------------------------
					# We have a default channel_id to go
					#-------------------------------------
					&asterisk_debug_print("Accept channel_id=$call_data{prompt_noinput_logic} by prompt_noinput_logic=NUMBER");
					%channel_data = &search_channel_by_channel_id($digits);
					if ($channel_data{ok} eq 1) { &start_channel_session(%channel_data); } else {&asterisk_debug_print("No channel_id found"); &radio_prompt_play($call_data{radio_station_id},"extension_error"); }
				}
			}
		}
	}
}
#
#-------------------------------------
# end 
#-------------------------------------

&asterisk_debug_print("========================================================");
&asterisk_debug_print("Dump data to help debug");
&asterisk_debug_print("========================================================");
foreach(sort keys %call_data) {if (index($_,"call_") ne 0) {next}&asterisk_debug_print("CALL DATA DUMP $_ = $call_data{$_}");}
foreach(sort keys %call_data) {if (index($_,"call_") eq 0) {next}&asterisk_debug_print("GENERIC DATA DUMP $_ = $call_data{$_}");}
&asterisk_debug_print("========================================================");
&asterisk_debug_print("$call_data{system_agi}  (STOP)");
&asterisk_debug_print("========================================================");
&hangup_this_call();
#======================================================





#======================================================
# radio libs
#======================================================
sub search_channel_by_digits(){
	local($d) = @_;
	local(%data);
	%data = ();
	$data{ok}		= 0;
	$data{digits}	= $d;
	if ( exists($call_data{radio_channels_ext2ids}{$d}) ) {
		$data{id}			= $call_data{radio_channels_ext2ids}{$d};
		$data{ok}			= 1;
		$data{listen_pin}	= $call_data{radio_channels_listen_pin}{$data{id}};
	}
	return %data;
}
sub search_channel_by_channel_id(){
	local($i) = @_;
	local(%data);
	%data = ();
	$data{ok}		= 0;
	$data{id}		= $i;
	if ( exists($call_data{radio_channels_ids2ext}{$i}) ) {
		$data{digits}		= $call_data{radio_channels_ids2ext}{$1};
		$data{ok}			= 1;
		$data{listen_pin}	= $call_data{radio_channels_listen_pin}{$data{id}};
	}
	return %data;
}
sub start_channel_session(){
	local(%extension_data) = @_;
	local(%hash,$music_on_hold_id);
	&asterisk_debug_print("RADIO SESSION: === START=== ");
	&asterisk_debug_print("RADIO SESSION: sessions_in_this_call = $call_data{radio_session_count} ");
	foreach (sort keys %extension_data) {&asterisk_debug_print("RADIO SESSION: data $_=$extension_data{$_}");}
	# we need $call_data{radio_channel_id} to help get/set_data functions
	
	$call_data{radio_channel_id} = $extension_data{id};
	#
	#-------------------------------------
	# check listen_pin
	#-------------------------------------
	if ($extension_data{listen_pin} ne "") {
		$extension_data{listen_pin_approved_by_user_input} = 0;
		&asterisk_debug_print("RADIO SESSION: listen_pin need for this channel. lets see what we can do");
		#
		# try remember last pin
		if ($extension_data{listen_pin_approved_by_user_input} eq 0) {
			$tmp1 = "Last_pin_for_".$extension_data{$id};
			$tmp2 = clean_int(&asterisk_get_variable($tmp1));
			if ($tmp2 ne "") {
				&asterisk_debug_print("RADIO SESSION: we remember last user pin for this channel. lets try");
				if (index(",$extension_data{listen_pin},",",$tmp2,") ne -1) {
					&asterisk_debug_print("RADIO SESSION: CORRECT listen_pin. Lets approve this session");
					&radio_prompt_play($call_data{radio_station_id},"listen_pin_ok");
					$extension_data{listen_pin_approved_by_user_input} = 1;
				} else {
					&asterisk_debug_print("RADIO SESSION: last pin is not valid anymore. lets ask pin again.");
				}
			}
		}
		#
		# ask pin by digits 
		if ($extension_data{listen_pin_approved_by_user_input} eq 0) {
			foreach (1..3){
				&asterisk_debug_print("RADIO SESSION: lets ask ($_ of 3)");
				$listen_pin_digits = &asterisk_collect_digits(&radio_prompt_get_id($call_data{radio_station_id},"listen_pin_question"));
				if ( ($listen_pin_digits ne "") && (index(",$extension_data{listen_pin},",",$listen_pin_digits,") ne -1) ) {
					&asterisk_debug_print("RADIO SESSION: CORRECT listen_pin. Lets approve this session");
					&radio_prompt_play($call_data{radio_station_id},"listen_pin_ok");
					$extension_data{listen_pin_approved_by_user_input} = 1;
					&asterisk_set_variable("Last_pin_for_".$extension_data{$id},$listen_pin_digits);
					last;
				} else {
					&asterisk_debug_print("RADIO SESSION: Incorrect listen_pin for digits=$listen_pin_digits");
					&radio_prompt_play($call_data{radio_station_id},"listen_pin_error");
				}
			}
		}
		# reject if not approved
		if ($extension_data{listen_pin_approved_by_user_input} eq 0) {
			&asterisk_debug_print("RADIO SESSION: User did not enter correct listen_pin, lets reject this radio session request.");
			exit;
		}
	}
	#
	#-------------------------------------
	# start session log 
	#-------------------------------------
	$sql_clientid_name  = ($call_data{client_id_is_unknown} eq 1) ? "" : "radio_data_client_id, ";
	$sql_clientid_value = ($call_data{client_id_is_unknown} eq 1) ? "" : "'$call_data{client_id}', ";
	$sql = &database_scape_sql(
		"
		insert into radio_log_session 
		(datetime_start,  ani,  did,  digits_selected_by_user, digits, $sql_clientid_name   radio_data_station_id, radio_data_station_channel_id,  ast_unique_id, system_host ) values 
		(now(),                   '%s', '%s', '%s',                    '%s',   $sql_clientid_value  '%s',                  '%s',                           '%s',          '%s'        ) 
		",
		$call_data{call_ani},
		$call_data{call_did}, 
		$extension_data{selected_by_user},
		$extension_data{digits},
		$call_data{radio_station_id},
		$extension_data{id}, 
		$call_data{call_uniqueid},
		$call_data{system_host} 
	);
	$call_data{radio_log_listen_session_id} = &database_do_insert($sql); 
	&set_client_data_at_this_station("session_count","+");
	&set_client_data_at_this_station("session_last_date","NOW");
	&set_client_data_at_this_station("session_last_log_id",$call_data{radio_log_listen_session_id});
	&set_client_data_at_this_channel("session_count","+");
	&set_client_data_at_this_channel("session_last_date","NOW");
	&set_client_data_at_this_channel("session_last_log_id",$call_data{radio_log_listen_session_id});
	&set_client_data_at_this_station("last_digits",$extension_data{digits});
	&set_client_data_at_this_station("last_digits_timestamp",time);
	#
	#-------------------------------------
	# save at variables
	#-------------------------------------
	$tmp1 = sprintf("%x",$call_data{radio_log_listen_session_id});
	$tmp2 = hex($tmp1);
	&asterisk_debug_print("RADIO SESSION: conference_name=$extension_data{id}");
	&asterisk_debug_print("RADIO SESSION: conference_data=$call_data{radio_log_listen_session_id}");
	&asterisk_debug_print("RADIO SESSION: conference_data_hex=$tmp1 / $tmp2");
	asterisk_set_variable("conference_name",$extension_data{id});
	asterisk_set_variable("conference_data",$call_data{radio_log_listen_session_id});
	asterisk_set_variable("conference_data_hex",$tmp1);
	#
	#-------------------------------------
	# exit
	#-------------------------------------
	# Exit this AGI. We dont need stay up wait for call finish. 
	# app_konference.pl listener will handle billing by conference_data variable
	# asterisk dialplan will call agi again if need
	# agi check infinit loop at top and hangup if need
	&asterisk_debug_print("RADIO SESSION: === STOP === ");
	exit 0;
}
#sub get_data_from_actual_listener(){
#	local($name) = @_;
#	local($station_id,$ani) = @_;
#	$station_id	= substr(&clean_int($call_data{radio_station_id}),0,100);
#	$ani 		= substr(&clean_int($call_data{call_ani}),0,32);
#	return &radio_data_station_ani_get($station_id,$ani,$name);
#}
#sub set_data_from_actual_listener(){
#	local($name,$value) = @_;
#	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
#	local($ani,$station_id);
#	$station_id	= substr(&clean_int($call_data{radio_station_id}),0,100);
#	$ani 		= substr(&clean_int($call_data{call_ani}),0,32);
#	return &radio_data_station_ani_set($station_id,$ani,$name,$value);
#}



# =================================================
# data lib
# =================================================
sub get_client_data_at_this_channel(){
	local($name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($client_id,$channel_id);
	#
	# get keys
	$channel_id	= $call_data{radio_channel_id};
	$client_id 	= &get_client_id_for_this_call();
	#
	# check keys
	if ($channel_id	eq "") {return "";} 
	if ($client_id	eq "") {return "";} 
	#
	# return data
	return &radio_data_client_channel_get($client_id,$channel_id,$name);
}
sub set_client_data_at_this_channel(){
	local($name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($client_id,$channel_id);
	#
	# get keys
	$channel_id	= $call_data{radio_channel_id};
	$client_id 	= &get_client_id_for_this_call();
	#
	# check keys
	if ($channel_id	eq "") {return 0;} 
	if ($client_id	eq "") {return 0;} 
	#
	# return data
	return &radio_data_client_channel_set($client_id,$channel_id,$name,$value);
}
sub get_client_data_at_this_station(){
	local($name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($client_id,$station_id);
	#
	# get keys
	$station_id	= $call_data{radio_station_id};
	$client_id 	= &get_client_id_for_this_call();
	#
	# check keys
	if ($station_id	eq "") {return "";} 
	if ($client_id	eq "") {return "";} 
	#
	# return data
	return &radio_data_client_station_get($client_id,$station_id,$name);
}
sub set_client_data_at_this_station(){
	local($name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($client_id,$station_id);
	#
	# get keys
	$station_id	= $call_data{radio_station_id};
	$client_id 	= &get_client_id_for_this_call();
	#
	# check keys
	if ($station_id	eq "") {return 0;} 
	if ($client_id	eq "") {return 0;} 
	#
	# return data
	return &radio_data_client_station_set($client_id,$station_id,$name,$value);
}
sub get_client_id_for_this_call(){
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($ani,$station_id);
	# right now we have only ani, but in future, sip-headers from phono web-phone
	# will give facebook or google ids to use as key (and not only ani as key)
	# if no client found, try to create a new one, assign key
	# Better cache this call to save resource
	#
	# cache
	if (exists($call_data{client_id_is_unknown})) { if ($call_data{client_id_is_unknown} eq 1) {return "";} }
	if (exists($call_data{client_id})) { if ($call_data{client_id} ne "") {return $call_data{client_id};} }
	#
	# decide key to use (right now only ani)
	# if we have multiple options, try facebook, google and then ani
	$call_data{client_id_key_type}	= "";
	$call_data{client_id_key} 		= "";
	if ($call_data{client_id_key_type} eq "") {
		$ani = substr(&clean_int($call_data{call_ani}),0,32);
		if ($ani ne "") {
			$call_data{client_id_key_type}	= "ANI";
			$call_data{client_id_key} 		= $ani;
		}
	}
	#
	# stop if no key
	if ($call_data{client_id_key_type} eq "") {
		$call_data{client_id_is_unknown}=1;
		return "";
	}
	#
	# now we have key, lets find client_id and create if necessary
	$call_data{client_id} = "";
	if ($call_data{client_id_key_type} eq "ANI"		) { $call_data{client_id} = &radio_data_client_getid_by_ani($call_data{client_id_key}) }
	if ($call_data{client_id_key_type} eq "FACEBOOK") { $call_data{client_id} = &radio_data_client_getid_by_facebook($call_data{client_id_key}) }
	if ($call_data{client_id_key_type} eq "GOOGLE"	) { $call_data{client_id} = &radio_data_client_getid_by_google($call_data{client_id_key}) }
	#
	# return if found something 
	if ($call_data{client_id} ne "") {
		delete($call_data{client_id_is_unknown});
		return $call_data{client_id};
	}
	#
	# ok, we need create this litle guy
	$call_data{client_id} = &radio_data_client_new();
	if ($call_data{client_id} eq "") { $call_data{client_id_is_unknown} =1; return ""; }
	if ($call_data{client_id_key_type} eq "ANI"		) { &radio_data_client_set($call_data{client_id},"ani",			$call_data{client_id_key}); }
	if ($call_data{client_id_key_type} eq "FACEBOOK") { &radio_data_client_set($call_data{client_id},"facebook_id",	$call_data{client_id_key}); }
	if ($call_data{client_id_key_type} eq "GOOGLE"	) { &radio_data_client_set($call_data{client_id},"google_id",	$call_data{client_id_key}); }
	delete($call_data{client_id_is_unknown});
	return $call_data{client_id};
}
# =================================================



sub radio_prompt_get_id(){
	local($station_id,$prompt_action) = @_;
	local(%prompt,$hash,$sql,$prompt_name,$prompt_id,$prompt_file);
	#
	# create static data
	#$prompt_folder = "/usr/share/asterisk/sounds/";
	$prompt_folder = "/var/lib/asterisk/sounds/";
	%prompt = ();
	$prompt{welcome}						= "multilevel-multiradio-welcome";
	$prompt{too_much_questions}				= "goodbye";
	$prompt{help}							= "";
	$prompt{extension_question}				= "multilevel-multiradio-radio-prompt";
	$prompt{extension_error}				= "multilevel-pbxbyani-radio-incorrect-exten";
	$prompt{extension_favorite_announce_1}	= "multilevel-multiradio-listen-1";
	$prompt{extension_favorite_announce_2}	= "multilevel-multiradio-listen-2";
	$prompt{extension_favorite_announce_3}	= "multilevel-multiradio-listen-3";
	$prompt{extension_favorite_announce_4}	= "multilevel-multiradio-listen-4";
	$prompt{extension_favorite_announce_5}	= "multilevel-multiradio-listen-5";
	$prompt{extension_favorite_announce_6}	= "multilevel-multiradio-listen-6";
	$prompt{extension_favorite_announce_7}	= "multilevel-multiradio-listen-7";
	$prompt{extension_favorite_announce_9}	= "multilevel-multiradio-listen-9";
	$prompt{extension_favorite_announce_8}	= "multilevel-multiradio-listen-8";
	$prompt{listen_pin_question}			= "conf-getpin";
	$prompt{listen_pin_ok}					= "";
	$prompt{listen_pin_error}				= "conf-invalidpin";
	#
	# check basic
	unless (exists($prompt{$prompt_action})) {
		#&asterisk_debug_print("RADIO_PROMPT: unknown prompt=$prompt_action ");
		return "";
	}
	$station_id = clean_int($station_id);
	if ($station_id eq "") {
		#&asterisk_debug_print("RADIO_PROMPT: unknown station_id=$station_id");
		return "";
	}
	#
	# check database
	#&asterisk_debug_print("RADIO_PROMPT: search $prompt_action prompt for station_id=$station_id");
	$sql = "
	select 1,1,p.id,unix_timestamp(p.prompt_last_change),p.title
	from radio_data_station as s,radio_data_station_prompt as p
	where s.prompt_$prompt_action = p.id and s.id= '$station_id'
	";
	%hash = &database_select_as_hash($sql,"flag,id,time,title");
	if ($hash{1}{flag} ne 1){
		#&asterisk_debug_print("RADIO_PROMPT: No custom prompt, play default $prompt{$prompt_action}");
		return $prompt{$prompt_action};
	} else {
		$prompt_id		= $hash{1}{id};
		$prompt_name	= "radio-prompt-".$station_id."-".$prompt_action."-".$hash{1}{time};
		$prompt_name	= "radio-prompt-".$station_id."-".$hash{1}{time};
		$prompt_file	= $prompt_folder."/".$prompt_name.".gsm";
		#&asterisk_debug_print("RADIO_PROMPT: Found custom prompt");
		#&asterisk_debug_print("RADIO_PROMPT: title=$hash{1}{title}");
		#&asterisk_debug_print("RADIO_PROMPT: id=$prompt_id");
		#&asterisk_debug_print("RADIO_PROMPT: name=$prompt_name");
		#&asterisk_debug_print("RADIO_PROMPT: file=$prompt_file");
		unless (-e $prompt_file) {
			#&asterisk_debug_print("RADIO_PROMPT: file does not exists. try to download");
			my $output = $database->prepare("SELECT prompt_data FROM radio_data_station_prompt where id='$prompt_id'  ");	
			$output->execute;
			my ($prompt_data) = $output->fetchrow_array;
			open(OUT,">$prompt_file");
			binmode OUT;
			print OUT $prompt_data;	
			close(OUT);
		}
		if (-e $prompt_file) {
			#&asterisk_debug_print("RADIO_PROMPT: play prompt=$prompt_name");
			return $prompt_name;
		} else {			
			#&asterisk_debug_print("RADIO_PROMPT: No custom prompt, play default $prompt{$prompt_action}");
			return $prompt{$prompt_action};
		}
	}	
}
sub radio_prompt_play(){
	local($station_id,$prompt_action) = @_;
	local($tmp);
	$tmp = &radio_prompt_get_id($station_id,$prompt_action);
	if ($tmp eq "") {return 0}
	&asterisk_play($tmp);
	return 1;
}
sub hangup_this_call(){
	&asterisk_debug_print("=== finish (no Hangup) this call");
	&asterisk_hangup();	
	exit 0;
}
#======================================================








#======================================================
# asterisk lib
#======================================================
sub asterisk_debug_print(){
	my ($l) = @_;
	if ($asterisk_debug_switch_screen 	eq 1) { $AGI->verbose(&clean_str($l,"\\/()-_+=:,[]><#*"),1);	}
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

#======================================================





