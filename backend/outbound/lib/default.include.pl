#!/usr/bin/perl
################################################################################
#
# global libs for AGI, perl scripts and CGI
# extra libs for multilevel services  
# developed for years to zenofon
#
################################################################################
$|=1;$!=1; # disable buffer 
use File::Copy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;
use LWP 5.69;
use Logger::Syslog;
use Asterisk::AMI;
use Data::Dumper;
use Carp; $SIG{ __DIE__ } = sub { Carp::confess( @_ ) };
$app_root							= "/usr/local/owsline/";
$host_name							= "neyfrota-dev";
%template_buffer					= ();
$database 							= null;
$conection 							= null;
$database_connected					= 0;
$database_last_error				= "";
# in future, move database settings to externalfile. 
# Use hardcode make life complex to manage production and multiple development base
# all other data need leave in database
$database_dsn						= "dbi:mysql:owsline:127.0.0.1:3306";
$database_user						= "owsline";
$database_password					= "root";
$asterisk_manager_is_connected		= 0;
$asterisk_manager_connection		= null;
$asterisk_manager_response			= null;
$asterisk_manager_ip				= "127.0.0.1";
$asterisk_manager_port				= "5038";
$asterisk_manager_user				= "admin";
$asterisk_manager_secret			= "amp111";
$im_identify						= "/usr/bin/identify";
$im_convert							= "/usr/bin/convert";
$im_composite						= "/usr/bin/composite";
#
# in future, make this thing permanent in modperl.
# TODO: do we really need that? are we using that?
%global_cache	= (); 
%cache_request	= ();
%cache_session	= ();
%cache_user		= ();
%cache_global	= ();
#
# hard code hosts
$hardcoded_call_server_ip 	= "127.0.0.1";
$hardcoded_stream_server_ip = "127.0.0.1";
#$hardcoded_stream_server_ip = "10.0.1.9";
$hardcoded_call_server 		= "local";
$hardcoded_stream_server 	= "local";
$hardcoded_webservice_host	= "www.uslove.com";
return 1;
#=======================================================





#=======================================================
# radio_data_client lib
#=======================================================
# This help to get/set data from clients.
# we have 3 client data levels.
# - First level its data that belong to THIS client, like name, email, username, password etc etc. You just need inform client_id
# - Second is client data in ONE station. Things like tags statistics. You need inform client_id and station_id
# - 3rd is client data in ONE channel. Things like permissions, statistics. You need inform client_id and channel_id
#
# tables:
# we create new tables for this new client structure, but we also need change radio_log_session table
# ALTER TABLE `owsline`.`radio_log_session` ADD COLUMN `radio_data_client_id` BIGINT UNSIGNED AFTER `digits`;
#
# This are client specific data
# basic proto code is: "set(client,name,value)" to save, "value=get(client,name)" to read and "client=new()" to create new client 
# - name can be whatever field you want. API try to get data from main table and if field you ask does not exists, auto-map at extradata table
# - client is a numeric id. Use radio_data_client_getid_by_* helpers to find
# - value is a string (256 long) and sometimes special things like now() in creation_date field or numeric in ani field
sub radio_data_client_new(){
	return &database_do_insert("insert into radio_data_client (creation_date) values (now()) ");
}
sub radio_data_client_set(){
	local($client_id,$name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$sql_value);
	# clean
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$client_id	= substr(&clean_int($client_id),0,100);
	$ani 		= substr(&clean_int($ani),0,32);
	$value 		= substr(&clean_str($value,"SQLSAFE"),0,255);
	# check
	if ($client_id eq "")	{return 0}
	if ($name eq "")		{return 0}
	%hash = &database_select_as_hash("select 1,1 from radio_data_client where id='$client_id' ","flag");
	if ($hash{1}{flag} ne 1){return 0}
	# action
	if (index("|ani|facebook_id|google_id|creation_date|name|email|","|$name|") ne -1 ) {
		$sql_value = "";
		if 	  ($name eq "creation_date")	{ $sql_value = ($value eq "NOW") ? "now()" : "'".&clean_int($value)."'"; 	}
		elsif ($name eq "ani") 				{ $sql_value = "'".&clean_int($value)."'"; 									}
		else								{ $sql_value = "'".$value."'"; 												}
		&database_do("update radio_data_client set $name=$value where id='$client_id' ");
	} else {
		%hash  = &database_select_as_hash("select 1,1 from radio_data_client_extradata where target='$client_id' and name='$name' ","flag");
		if ($hash{1}{flag} eq 1){
			&database_do("update radio_data_client_extradata set value='$value' where target='$client_id' and name='$name' ");
		} else {
			&database_do("insert into radio_data_client_extradata (target,name,value) values ('$client_id','$name','$value') ");
		}
	}
	return 1
}
sub radio_data_client_get(){
	# you send client_id (numeric) and field name (string). api return value for this field
	# We try first read/write at radio_data_client table and the, if fail, at radio_data_client_extradata table 
	local($client_id,$name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($value);
	# clean
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$value		= "";
	$client_id	= substr(&clean_int($client_id),0,100);
	# check
	if ($client_id eq "")	{return $value;}
	if ($name eq "")		{return $value;}
	# action
	$sql = "";
	if 	  ($name eq "creation_date")	{ $sql = "select 1,1,unix_timestamp(creation_date) from radio_data_client where id='$client_id' "; }
	elsif ($name eq "ani") 				{ $sql = "select 1,1,ani from radio_data_client where id='$client_id' "; }
	elsif ($name eq "facebook_id") 		{ $sql = "select 1,1,facebook_id from radio_data_client where id='$client_id' "; }
	elsif ($name eq "google_id") 		{ $sql = "select 1,1,google_id from radio_data_client where id='$client_id' "; }
	elsif ($name eq "name") 			{ $sql = "select 1,1,name from radio_data_client where id='$client_id' "; }
	elsif ($name eq "email") 			{ $sql = "select 1,1,email from radio_data_client where id='$client_id' "; }
	else 								{ $sql = "select 1,1,value from radio_data_client_extradata where target='$client_id' and name='$name' ";}
	if ($sql ne "") {
		%hash  = &database_select_as_hash($sql,"flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	}
	return $value
}
sub radio_data_client_getid_by_ani(){
	local($ani) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($value);
	$ani	= substr(&clean_int($ani),0,255);
	$value	= "";
	if ($ani eq "")	{return $value;}
	$sql = "select 1,1,id from radio_data_client where ani='$ani' order by creation_date limit 0,1";
	%hash  = &database_select_as_hash($sql,"flag,value");
	$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	return $value;
}
sub radio_data_client_getid_by_facebook(){
	local($facebook_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($value);
	$facebook_id	= substr(&clean_str($facebook_id,"MINIMAL","-_."),0,255);
	$value			= "";
	if ($facebook_id eq "")	{return $value;}
	$sql = "select 1,1,id from radio_data_client where facebook_id='$facebook_id' order by creation_date limit 0,1";
	%hash  = &database_select_as_hash($sql,"flag,value");
	$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	return $value;
}
sub radio_data_client_getid_by_google(){
	local($google_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($value);
	$google_id	= substr(&clean_str($google_id,"MINIMAL","-_."),0,255);
	$value		= "";
	if ($google_id eq "")	{return $value;}
	$sql = "select 1,1,id from radio_data_client where google_id='$google_id' order by creation_date limit 0,1";
	%hash  = &database_select_as_hash($sql,"flag,value");
	$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	return $value;
}


#
# This are client data at ONE station
# basic proto code is: "set(client,station,name,value)" to save, "value=get(client,station,name)" to read 
# - name can be whatever field you want. API try to get data from main table and if field you ask does not exists, auto-map at extradata table
# - client is a numeric id. Use radio_data_client_getid_by_* helpers to find
# - station is station_id (numeric)
# - value is a string (256 long) and sometimes special things like now() in creation_date field or numeric in ani field
sub radio_data_client_station_get_data_id_and_create_link_if_dont_exists(){
	local($client_id,$station_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$data_id);
	#
	# cache to avoid too much db hit.
	if (exists($global_cache{rdcsgdiaclide}{$client_id}{$station_id})) {
		return $global_cache{rdcsgdiaclide}{$client_id}{$station_id};
	}
	#
	# clean
	$client_id	= substr(&clean_int($client_id),0,100);
	$station_id	= substr(&clean_int($station_id),0,100);
	$data_id	= "";
	#
	# check client
	%hash = &database_select_as_hash("select 1,1 from radio_data_client where id='$client_id' ","flag");
	if ($hash{1}{flag} ne 1){return ""}
	#
	# check station
	%hash = &database_select_as_hash("select 1,1 from radio_data_station where id='$station_id' ","flag");
	if ($hash{1}{flag} ne 1){return ""}
	#
	# check data_id
	%hash = &database_select_as_hash("select 1,1,id from radio_data_client_station where radio_data_client_id='$client_id' and radio_data_station_id='$station_id' order by creation_date limit 0,1 ","flag,value");
	if ($hash{1}{flag} eq 1) {
		$data_id = $hash{1}{value};
	} else {
		&database_do_insert("insert into radio_data_client_station (creation_date,radio_data_client_id,radio_data_station_id) values (now(),'$client_id','$station_id') ");
		%hash = &database_select_as_hash("select 1,1,id from radio_data_client_station where radio_data_client_id='$client_id' and radio_data_station_id='$station_id' order by creation_date limit 0,1 ","flag,value");
		if ($hash{1}{flag} eq 1) {
			$data_id = $hash{1}{value};
		} else {
			$data_id = "";
		}
	}
	#
	# save cache and return
	$global_cache{rdcsgdiaclide}{$client_id}{$station_id} = $data_id;
	return $data_id;
}
sub radio_data_client_station_set(){
	local($client_id,$station_id,$name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$sql_value,$data_id);
	#
	# check/clean ids
	$client_id	= substr(&clean_int($client_id),0,100);
	$station_id	= substr(&clean_int($station_id),0,100);
	if ($client_id eq "")	{return 0}
	if ($station_id eq "")	{return 0}
	$data_id	= &radio_data_client_station_get_data_id_and_create_link_if_dont_exists($client_id,$station_id);
	if ($data_id eq "")	{return 0}
	#
	# check/clean data
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$value 		= substr(&clean_str($value,"SQLSAFE"),0,255);
	if ($name eq "")		{return 0}
	#
	# action
	if (index("|creation_date|","|$name|") ne -1 ) {
		# this is read only
	} elsif (index("|session_count|session_last_date|session_last_log_id|name|tag_0|tag_1|tag_2|tag_3|tag_4|tag_5|tag_6|tag_7|tag_8|tag_9|","|$name|") ne -1 ) {
		# save in main table
		$sql_value = "'".$value."'";
		if 	  ($name eq "session_last_date")	{ $sql_value = ($value eq "NOW") ? "now()" : "'".&clean_int($value)."'"; 	}
		elsif ($name eq "session_count") 		{
			if    ($value eq "")	{ $sql_value = "0" }
			elsif ($value eq "+")	{ $sql_value = "$name + 1" }
			elsif ($value eq "-")	{ $sql_value = "$name - 1" }
			else   					{ $sql_value = "'".&clean_int($value)."'"; } 
		}
		elsif ($name eq "session_last_log_id") 	{ $sql_value = ($value eq "") ? "null" : "'".&clean_int($value)."'"; 		}
		elsif ($name eq "tag_0")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_1")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_2")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_3")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_4")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_5")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_6")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_7")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_8")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		elsif ($name eq "tag_9")			 	{ $sql_value = ($value eq 1) ? "1" : "0"; 									}
		&database_do("update radio_data_client_station set $name=$sql_value where id='$data_id' ");
	} else {
		# save in extradata table
		%hash  = &database_select_as_hash("select 1,1 from radio_data_client_station_extradata where radio_data_client_station_id='$data_id' and name='$name' ","flag");
		if ($hash{1}{flag} eq 1){
			&database_do("update radio_data_client_station_extradata set value='$value' where radio_data_client_station_id='$data_id' and name='$name' ");
		} else {
			&database_do("insert into radio_data_client_station_extradata (radio_data_client_station_id,name,value) values ('$data_id','$name','$value') ");
		}
	}
	return 1
}
sub radio_data_client_station_get(){
	local($client_id,$station_id,$name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$sql_value,$data_id,$value);
	$value = "";
	#
	# check/clean ids
	$client_id	= substr(&clean_int($client_id),0,100);
	$station_id	= substr(&clean_int($station_id),0,100);
	if ($client_id eq "")	{return $value}
	if ($station_id eq "")	{return $value}
	$data_id	= &radio_data_client_station_get_data_id_and_create_link_if_dont_exists($client_id,$station_id);
	if ($data_id eq "")	{return $value}
	#
	# check/clean data
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	if ($name eq "")		{return $value}
	#
	# action
	$sql = "";
	if 	  ($name eq "creation_date")		{ $sql = "select 1,1,unix_timestamp(creation_date) from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "name") 				{ $sql = "select 1,1,name from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "session_last_date")	{ $sql = "select 1,1,unix_timestamp(session_last_date) from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "session_count") 		{ $sql = "select 1,1,session_count from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "session_last_log_id") 	{ $sql = "select 1,1,session_last_log_id from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_0") 				{ $sql = "select 1,1,tag_0 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_1") 				{ $sql = "select 1,1,tag_1 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_2") 				{ $sql = "select 1,1,tag_2 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_3") 				{ $sql = "select 1,1,tag_3 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_4") 				{ $sql = "select 1,1,tag_4 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_5") 				{ $sql = "select 1,1,tag_5 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_6") 				{ $sql = "select 1,1,tag_6 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_7") 				{ $sql = "select 1,1,tag_7 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_8") 				{ $sql = "select 1,1,tag_8 from radio_data_client_station where id='$data_id' "; }
	elsif ($name eq "tag_9") 				{ $sql = "select 1,1,tag_9 from radio_data_client_station where id='$data_id' "; }
	else 									{ $sql = "select 1,1,value from radio_data_client_station_extradata where radio_data_client_station_id='$data_id' and name='$name' ";}
	if ($sql ne "") {
		%hash  = &database_select_as_hash($sql,"flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	}
	return $value
}
#
# This are client data at ONE channel
# basic proto code is: "set(client,channel,name,value)" to save, "value=get(client,channel,name)" to read 
# - name can be whatever field you want. API try to get data from main table and if field you ask does not exists, auto-map at extradata table
# - client is a numeric id. Use radio_data_client_getid_by_* helpers to find
# - channel is channel_id (numeric)
# - value is a string (256 long) and sometimes special things like now() in creation_date field or numeric in ani field
sub radio_data_client_channel_get_data_id_and_create_link_if_dont_exists(){
	local($client_id,$channel_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$data_id);
	#
	# cache to avoid too much db hit.
	if (exists($global_cache{rdccgdiaclide}{$client_id}{$channel_id})) {
		return $global_cache{rdccgdiaclide}{$client_id}{$channel_id};
	}
	#
	# clean
	$client_id	= substr(&clean_int($client_id),0,100);
	$channel_id	= substr(&clean_int($channel_id),0,100);
	$data_id	= "";
	#
	# check client
	%hash = &database_select_as_hash("select 1,1 from radio_data_client where id='$client_id' ","flag");
	if ($hash{1}{flag} ne 1){return ""}
	#
	# check channel
	%hash = &database_select_as_hash("select 1,1 from radio_data_station_channel where id='$channel_id' ","flag");
	if ($hash{1}{flag} ne 1){return ""}
	#
	# check data_id
	%hash = &database_select_as_hash("select 1,1,id from radio_data_client_channel where radio_data_client_id='$client_id' and radio_data_channel_id='$channel_id' order by creation_date limit 0,1 ","flag,value");
	if ($hash{1}{flag} eq 1) {
		$data_id = $hash{1}{value};
	} else {
		&database_do_insert("insert into radio_data_client_channel (creation_date,radio_data_client_id,radio_data_channel_id) values (now(),'$client_id','$channel_id') ");
		%hash = &database_select_as_hash("select 1,1,id from radio_data_client_channel where radio_data_client_id='$client_id' and radio_data_channel_id='$channel_id' order by creation_date limit 0,1 ","flag,value");
		if ($hash{1}{flag} eq 1) {
			$data_id = $hash{1}{value};
		} else {
			$data_id = "";
		}
	}
	#
	# save cache and return
	$global_cache{rdccgdiaclide}{$client_id}{$channel_id} = $data_id;
	return $data_id;
}
sub radio_data_client_channel_set(){
	local($client_id,$channel_id,$name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$sql_value,$data_id);
	#
	# check/clean ids
	$client_id	= substr(&clean_int($client_id),0,100);
	$channel_id	= substr(&clean_int($channel_id),0,100);
	if ($client_id eq "")	{return 0}
	if ($channel_id eq "")	{return 0}
	$data_id	= &radio_data_client_channel_get_data_id_and_create_link_if_dont_exists($client_id,$channel_id);
	if ($data_id eq "")	{return 0}
	#
	# check/clean data
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$value 		= substr(&clean_str($value,"SQLSAFE"),0,255);
	if ($name eq "")		{return 0}
	#
	# action
	if (index("|creation_date|","|$name|") ne -1 ) {
		# this is read only
	} elsif (index("|session_count|session_last_date|session_last_log_id|talk_pin|","|$name|") ne -1 ) {
		# save in main table
		$sql_value = "'".$value."'";
		if 	  ($name eq "session_last_date")	{ $sql_value = ($value eq "NOW") ? "now()" : "'".&clean_int($value)."'"; 	}
		elsif ($name eq "session_count") 		{
			if    ($value eq "")	{ $sql_value = "0" }
			elsif ($value eq "+")	{ $sql_value = "$name + 1" }
			elsif ($value eq "-")	{ $sql_value = "$name - 1" }
			else 					{ $sql_value = "'".&clean_int($value)."'"; } 
		}
		elsif ($name eq "session_last_log_id") 	{ $sql_value = ($value eq "") ? "null" : "'".&clean_int($value)."'"; 		}
		elsif ($name eq "talk_pin") 			{ $sql_value = ($value eq "") ? "null" : "'".&clean_int($value)."'"; 		}
		&database_do("update radio_data_client_channel set $name=$sql_value where id='$data_id' ");
	} else {
		# save in extradata table
		%hash  = &database_select_as_hash("select 1,1 from radio_data_client_channel_extradata where radio_data_client_channel_id='$data_id' and name='$name' ","flag");
		if ($hash{1}{flag} eq 1){
			&database_do("update radio_data_client_channel_extradata set value='$value' where radio_data_client_channel_id='$data_id' and name='$name' ");
		} else {
			&database_do("insert into radio_data_client_channel_extradata (radio_data_client_channel_id,name,value) values ('$data_id','$name','$value') ");
		}
	}
	return 1
}
sub radio_data_client_channel_get(){
	local($client_id,$channel_id,$name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql,$sql_value,$data_id,$value);
	$value = "";
	#
	# check/clean ids
	$client_id	= substr(&clean_int($client_id),0,100);
	$channel_id	= substr(&clean_int($channel_id),0,100);
	if ($client_id eq "")	{return $value}
	if ($channel_id eq "")	{return $value}
	$data_id	= &radio_data_client_channel_get_data_id_and_create_link_if_dont_exists($client_id,$channel_id);
	if ($data_id eq "")	{return $value}
	#
	# check/clean data
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	if ($name eq "")		{return $value}
	#
	# action
	$sql = "";
	if 	  ($name eq "creation_date")		{ $sql = "select 1,1,unix_timestamp(creation_date) from radio_data_client_channel where id='$data_id' "; }
	elsif ($name eq "session_last_date")	{ $sql = "select 1,1,unix_timestamp(session_last_date) from radio_data_client_channel where id='$data_id' "; }
	elsif ($name eq "session_count") 		{ $sql = "select 1,1,session_count from radio_data_client_channel where id='$data_id' "; }
	elsif ($name eq "session_last_log_id") 	{ $sql = "select 1,1,session_last_log_id from radio_data_client_channel where id='$data_id' "; }
	elsif ($name eq "talk_pin") 			{ $sql = "select 1,1,talk_pin from radio_data_client_channel where id='$data_id' "; }
	else 									{ $sql = "select 1,1,value from radio_data_client_channel_extradata where radio_data_client_channel_id='$data_id' and name='$name' ";}
	if ($sql ne "") {
		%hash  = &database_select_as_hash($sql,"flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	}
	return $value
}
#
# This is old and will be deprecated. We need remove all calls to this code
sub radio_data_station_ani_set(){
	local($station_id,$ani,$name,$value) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	#
	# clean
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$station_id	= substr(&clean_int($station_id),0,100);
	$ani 		= substr(&clean_int($ani),0,32);
	$value 		= substr(&clean_str($value,"SQLSAFE"),0,255);
	#
	# check
	if ($ani eq "")			{return 0}
	if ($station_id eq "")	{return 0}
	if ($name eq "")		{return 0}
	#
	# action
	if (index("|talk_pin|first_session_date|last_session_date|last_session_log_id|name|flag_1|flag_2|flag_3|flag_4|flag_5|","|$name|") ne -1 ) {
		if ($name eq "first_session_date") {
			if ($value eq "NOW") { $value="now()" } else {$value = "'".&clean_int($value)."'";}
		} elsif ($name eq "last_session_date") {
			if ($value eq "NOW") { $value="now()" } else {$value = "'".&clean_int($value)."'";}
		} elsif ($name eq "last_session_log_id") {
			$value = "'".&clean_int($value)."'";
		} elsif ($name eq "name") {
			$value = "'".$value."'";
		} elsif ($name eq "talk_pin") {
			$value = "'".$value."'";
		} elsif ($name eq "flag_1") {
			$value = ($value eq 1) ? "'1'" : "'0'";
		} elsif ($name eq "flag_2") {
			$value = ($value eq 1) ? "'1'" : "'0'";
		} elsif ($name eq "flag_3") {
			$value = ($value eq 1) ? "'1'" : "'0'";
		} elsif ($name eq "flag_4") {
			$value = ($value eq 1) ? "'1'" : "'0'";
		} elsif ($name eq "flag_5") {
			$value = ($value eq 1) ? "'1'" : "'0'";
		}
		%hash  = &database_select_as_hash("select 1,1 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag");
		if ($hash{1}{flag} eq 1){
			&database_do("update radio_data_station_ani set $name=$value where ani='$ani' and radio_station_id='$station_id' ");
		} else {
			&database_do("insert into radio_data_station_ani (ani,radio_station_id,$name) values ('$ani','$station_id',$value) ");
		}
	} else {
		%hash  = &database_select_as_hash("select 1,1 from radio_data_station_ani_extradata where ani='$ani' and radio_station_id='$station_id' and name='$name' ","flag");
		if ($hash{1}{flag} eq 1){
			&database_do("update radio_data_station_ani_extradata set value='$value' where ani='$ani' and radio_station_id='$station_id' and name='$name' ");
		} else {
			&database_do("insert into radio_data_station_ani_extradata (ani,radio_station_id,name,value) values ('$ani','$station_id','$name','$value') ");
		}
	}
	return 1
}
sub radio_data_station_ani_get(){
	local($station_id,$ani,$name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,@array,$sql);
	local($value);
	#
	# clean
	$name 		= substr(&clean_str($name,"MINIMAL","-_."),0,255);
	$name 		= "\L$name";
	$station_id	= substr(&clean_int($station_id),0,100);
	$ani 		= substr(&clean_int($ani),0,32);
	#
	# check
	if ($ani eq "")			{return ""}
	if ($station_id eq "")	{return ""}
	if ($name eq "")		{return ""}
	#
	# action
	if ($name eq "first_session_date") {
		%hash  = &database_select_as_hash("select 1,1,unix_timestamp(first_session_date) from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : 0;
	} elsif ($name eq "last_session_date") {
		%hash  = &database_select_as_hash("select 1,1,unix_timestamp(last_session_date) from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : 0;
	} elsif ($name eq "last_session_log_id") {
		%hash  = &database_select_as_hash("select 1,1,unix_timestamp(last_session_log_id) from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	} elsif ($name eq "name") {
		%hash  = &database_select_as_hash("select 1,1,name from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	} elsif ($name eq "talk_pin") {
		%hash  = &database_select_as_hash("select 1,1,talk_pin from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	} elsif ($name eq "flag_1") {
		%hash  = &database_select_as_hash("select 1,1,flag_1 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{value} eq 1) ? 1 : 0;
	} elsif ($name eq "flag_2") {
		%hash  = &database_select_as_hash("select 1,1,flag_2 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{value} eq 1) ? 1 : 0;
	} elsif ($name eq "flag_3") {
		%hash  = &database_select_as_hash("select 1,1,flag_3 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{value} eq 1) ? 1 : 0;
	} elsif ($name eq "flag_4") {
		%hash  = &database_select_as_hash("select 1,1,flag_4 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{value} eq 1) ? 1 : 0;
	} elsif ($name eq "flag_5") {
		%hash  = &database_select_as_hash("select 1,1,flag_5 from radio_data_station_ani where ani='$ani' and radio_station_id='$station_id' ","flag,value");
		$value = ($hash{1}{value} eq 1) ? 1 : 0;
	} else {
		%hash  = &database_select_as_hash("select 1,1,value from radio_data_station_ani_extradata where ani='$ani' and radio_station_id='$station_id' and name='$name' ","flag,value");
		$value = ($hash{1}{flag} eq 1) ? $hash{1}{value} : "";
	}
	# 
	# return 
	return $value
}
#
# i dont know what is this. Maybe dont need live in default include
sub radio_get_active_sessions_of_channel(){
	local ($conference_name) = @_;	
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash,%hash1,%hash2);
	local ($host);
	#
	# get host (rightnow only local [empty] host)
	$host = "";
	#
	# get clients from both conferences and mix in one group
	%hash1 = &app_konference_list($host,$conference_name);
	%hash2 = &app_konference_list($host,$conference_name."P");
	$tmp = 0;
	foreach $tmp1 (keys %hash1){
		%{$data{$tmp}} = %{$hash1{$tmp1}};
		$tmp++;
	}
	foreach $tmp1 (keys %hash2){
		%{$data{$tmp}} = %{$hash2{$tmp1}};
		$data{$tmp}{type} = "PRIVATE";
		$tmp++;
	}
	return %data;
}
#=======================================================





#------------------------
# appkonference lib 
#------------------------
sub app_konference_channel_stream_connect(){
	local($host,$channel_id) = @_;
	local($response,%action,$tmp);
	$response = &RemoteAsterisk($host,"/konference_stream_connect/?stream_server_ip=$hardcoded_stream_server_ip&conference_id=$channel_id");
	return $response;
}
sub app_konference_channel_stream_disconnect(){
	local($host,$channel_id) = @_;
	local(%conference,$response,%action,$tmp);
	$response = &RemoteAsterisk($host,"/konference_stream_disconnect/?conference_id=$channel_id");
	return $response;
}

sub app_konference_channel_recording_connect(){
	local($host,$channel_id) = @_;
	local($response,%action,$tmp);
	$response = &RemoteAsterisk($host, "/konference_recording_connect/?stream_server_ip=$hardcoded_stream_server_ip&conference_id=$channel_id");
	return $response;
}
sub app_konference_channel_recording_disconnect(){
	local($host,$channel_id) = @_;
	local(%conference,$response,%action,$tmp);
	$response = &RemoteAsterisk($host, "/konference_recording_disconnect/?conference_id=$channel_id");
	return $response;
}

sub app_konference_list_summary(){
	#
	# Notes: All other app_konference_* calls will be only called by webservice and 
	# are just a mask to access api over web at :171 port
	# only app_konference_list_summary and app_konference_list will be used in both sides
	# (at web and also at call/stream services) so we have a magic host LOCAL that will
	# query local asterisk instead go to web api (and save one web access overhead)
	#
	local ($host) = @_;	
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	local (@hosts,$line);
	$host = substr(&clean_str($host,"MINIMAL"),0,100);
	%data = ();
	if ($host eq "LOCAL") {
		@answer = &asterisk_manager_command_simple_as_array("konference list");
	} else {
		@answer = &RemoteAsterisk_AsArray($host,"/konference_list");
	}
	foreach $line (@answer){
		# 0.........1.........2.........3.........4.........5.........6.........7.........8.........9.........10........11........12........13........14.........
		# 0123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
		# Name                 Members              Volume               Duration            
		# 21908                2                    0                    00:00:10
		$v1 = &trim(substr($line,0,18));
		if ($v1 ne &clean_int($v1)) {next}
		$v2 = &trim(substr($line,21,18));
		if (substr($v1,-1,1) eq "P") {
			$conference = &clean_int($v1);
			$qtd = $v2;
			$qtd++; $qtd--;
		} else {
			$conference = $v1;
			$qtd = $v2;
			$qtd--;
			$qtd = ($qtd < 0) ? 0 : $qtd;
		}
		$data{by_host}{$host}{qtd_total} += $qtd;
		$data{by_conference}{$conference}{qtd_total} += $qtd;
		$data{by_host_and_conference}{$host}{$conference}{qtd_total} += $qtd;
		$data{qtd_total} += $qtd;
	}
	return %data;
}
sub app_konference_list(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$conference_name) = @_;	
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	local ($line);
	$conference_name = substr(&clean_str($conference_name,"MINIMAL"),0,100);
	%data = ();
	if ($host eq "LOCAL") {
		@answer = &asterisk_manager_command_simple_as_array("konference list $conference_name ");
	} else {
		@answer = &RemoteAsterisk_AsArray($host,"/konference_list/?conference_id=$conference_name");
	}
	foreach $line (@answer){
		#$data{debug}{raw_lines} .= $line;
		# 0.........1.........2.........3.........4.........5.........6.........7.........8.........9.........10........11........12........13........14.........
		# 0123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
		# User #               Flags                Audio                Volume               Duration             Spy                  Channel                                                                         
		# 1                    qLR-105721           Muted                0:0                  00:00:05             *                    SIP/112233-00000003    
		# ---------------
		# read line
		# ---------------
		$v1 = &trim(substr($line,0,18));
		if ($v1 ne &clean_int($v1)) {next}
		$v2 = &trim(substr($line,21,18));
		$v3 = &trim(substr($line,42,18));
		$v4 = &trim(substr($line,63,18));
		$v5 = &trim(substr($line,84,18));
		$v6 = &trim(substr($line,105,18));
		$v7 = &trim(substr($line,126,100));
		if($v2 eq "Flags") {next}
		# ---------------
		# basic data
		# ---------------		
		($tmp1,$tmp2,$tmp3) = split(/\:/,$v5);
		$tmp1++; $tmp2++; $tmp3++;
		$tmp1--; $tmp2--; $tmp3--;
		$data{$v1}{duration_seconds}			= $tmp3+($tmp2*60)+($tmp1*3600);
		$data{$v1}{flags} 						= $v2;
		$data{$v1}{muted} 						= ($v3 eq "Muted") ? 1 : 0;
		$data{$v1}{duration} 					= $v5;
		$data{$v1}{conference_name} 			= $conference_name;
		$data{$v1}{user} 						= $v1;
		$data{$v1}{sip_channel} 				= $v7;
		$data{$v1}{volume_talk} 				= (split(/\:/,$v4))[0];
		$data{$v1}{volume_listen} 				= (split(/\:/,$v4))[1];
		$data{$v1}{type} 						= "UNKNOWN";
		$data{$v1}{radio_log_session_id_hex}	= "";
		$data{$v1}{radio_log_session_id}		= "";
		if  (index($v2,"LR") eq 0) {
			$data{$v1}{type} 						= "LISTENER";			
			$data{$v1}{radio_log_session_id_hex} 	= substr($v2,2,100);
			$data{$v1}{radio_log_session_id} 		= hex($data{$v1}{radio_log_session_id_hex});
		} elsif  (index($v2,"R") eq 0) {
			$data{$v1}{type} 						= "TALKER";			
			$data{$v1}{radio_log_session_id_hex} 	= substr($v2,1,100);
			$data{$v1}{radio_log_session_id} 		= hex($data{$v1}{radio_log_session_id_hex});
		} elsif  (index($v2,"Ccl") eq 0) {
			$data{$v1}{type} = "STREAM";			
		} elsif  (index($v2,"CcL") eq 0) {
			$data{$v1}{type} = "RECORDING";
		}
		# ---------------
		# extra data
		# ---------------		
		if ($data{$v1}{radio_log_session_id} ne "") {
	    	%hash = database_select_as_hash("SELECT 1,1,id,ani,did,radio_data_client_id,radio_data_station_id,radio_data_station_channel_id,poll_votes_count,poll_last_vote_value FROM radio_log_session where id='$data{$v1}{radio_log_session_id}'","flag,log_id,ani,did,client_id,station_id,channel_id,poll_votes_count,poll_last_vote_value");
		    if ($hash{1}{flag} eq 1) { 
		    	$data{$v1}{client_id}	= $hash{1}{client_id};
		    	$data{$v1}{client_id}	= $hash{1}{channel_id};
		    	$data{$v1}{station_id}	= $hash{1}{station_id};
		    	$data{$v1}{ani}			= $hash{1}{ani};
				$data{$v1}{ani_format} 	= &clean_str(&format_dial_number($data{$v1}{ani}),"MINIMAL","()-+_");
		    	$data{$v1}{did}			= $hash{1}{did};
		    	$data{$v1}{last_vote}	= $hash{1}{poll_last_vote_value};
		    	$data{$v1}{votes_count}	= $hash{1}{poll_votes_count};
		    	if ($data{$v1}{client_id} ne "") {
					$data{$v1}{name}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"name");
					$data{$v1}{flag_0}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_0");
					$data{$v1}{flag_1}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_1");
					$data{$v1}{flag_2}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_2");
					$data{$v1}{flag_3}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_3");
					$data{$v1}{flag_4}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_4");
					$data{$v1}{flag_5}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_5");
					$data{$v1}{flag_6}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_6");
					$data{$v1}{flag_7}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_7");
					$data{$v1}{flag_8}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_8");
					$data{$v1}{flag_9}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_9");
		    	}
		    }
		}	
	}
	return %data;
}
sub app_konference_listenervolume_down(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_listenervolume_down/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_listenervolume_up(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_listenervolume_up/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_talkvolume_down(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_talkvolume_down/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_talkvolume_up(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_talkvolume_up/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_kick(){
	#
	# kick one channel out of conference. Remember this is not hangup.
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	# TODO: clean channel to avoid attack
	&RemoteAsterisk($host,"/konference_kick/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_set_channel_mode(){
	#
	# change channel mode (listener/talker/private) for a specific active
	# channel at asterisk.
	#
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel,$mode) = @_;
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	$tmp = "";
	$tmp = ($mode eq "0"		) ? "0"	: $tmp;
	$tmp = ($mode eq "1"		) ? "1"	: $tmp;
	$tmp = ($mode eq "2"		) ? "2"	: $tmp;
	$tmp = ($mode eq "TALKER"	) ? "1"	: $tmp;
	$tmp = ($mode eq "LISTENER"	) ? "0"	: $tmp;
	$tmp = ($mode eq "PRIVATE"	) ? "2"	: $tmp;
	if ($tmp eq "") {return 0;}
	&RemoteAsterisk($host,"/setvar/?name=conference_type&value=$tmp&channel=".&cgi_url_encode($sip_channel));
	&RemoteAsterisk($host,"/konference_kick/?channel=".&cgi_url_encode($sip_channel));
	if($mode eq "1" || $mode eq 'TALKER'  ) {
		&RemoteAsterisk($host,"/setvar/?name=istalked&value=1&channel=".&cgi_url_encode($sip_channel));
	}
}

sub app_konference_get_channel_istalked(){

	local ($host,$sip_channel) = @_;
	$res = &RemoteAsterisk($host,"/getvar/?name=istalked&channel=".&cgi_url_encode($sip_channel));
	
	return int($res);
}

#------------------------
#
#------------------------
# remote asterisk
#------------------------
# todo: inplement webservices with api in each asterisk and connect this api calls to webservices
# right now, remote is disabled, only query local asterisk 
sub DELETEME_remote_asterisk_command(){
	local ($host,$asterisk_cmd) = @_;
	local($cmd,@ans);
	# todo: clean cmd to avoid attack
	# todo: JUST LOCAL RIGHT NOW: in futue, implement webservice at remote asterisks and use remote services
	@ans = `/usr/sbin/asterisk -rx "$asterisk_cmd" 2>\&1 `;
	return @ans;
}
sub RemoteAsterisk(){
	local($host_id,$url_path) = @_;
	local($browser,$response,$output);
	local($url);
	$url_path 	= (substr($url_path,0,1) ne "/") ? "/$url_path" : $url_path;
	#
	# ==========================================================================
	# host_id hardcoded for now
	# ==========================================================================
	# we need this id in a servers table. Each server has name, user/password,
	# ip, proto, tipo, etc etc ....
	$url 		= "http://$hardcoded_call_server_ip:171$url_path";
	# ==========================================================================
	#
	$browser	= null;
	$response	= null;
	$browser 	= LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 5);
	$response	= $browser->get($url);
	if ($response->is_success) {
		$output	= $response->content;
	} else {
		$output = "HTTP_ERROR_" . substr($response->status_line,0,3);
	}
	return($output);
}
sub RemoteAsterisk_AsArray(){
	local($host_id,$url_path) = @_;
	local($browser,$response,@output);
	local($url,$buf);
	$url_path 	= (substr($url_path,0,1) ne "/") ? "/$url_path" : $url_path;
	#
	# ==========================================================================
	# host_id hardcoded for now
	# ==========================================================================
	# we need this id in a servers table. Each server has name, user/password,
	# ip, proto, tipo, etc etc ....
	$url 		= "http://$hardcoded_call_server_ip:171$url_path";
	# ==========================================================================
	#
	$browser	= null;
	$response	= null;
	$browser 	= LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 5);
	@output		= ();
	$response	= $browser->get($url);
	if ($response->is_success) {
		@output = split(/\n/,$response->content);
	}
	return(@output);
}
#------------------------
#
#------------------------
# asterisk manager libs
#------------------------
sub asterisk_manager_connect() {
	if ($asterisk_manager_is_connected eq 1) {return 1}
	$asterisk_manager_connection = Asterisk::AMI->new(	PeerAddr => $asterisk_manager_ip,
														OriginateHack => 1, 
                                						PeerPort => $asterisk_manager_port,
                                						Username => $asterisk_manager_user,
                                						Secret   => $asterisk_manager_secret
                         							);
	$asterisk_manager_is_connected = 1;
	return 1;
}
sub asterisk_manager_check_connection() {
	if ($asterisk_manager_is_connected eq 1) {return 1}
	return &asterisk_manager_connect();
}
sub asterisk_manager_command() {
        local(%my_action) = @_;
        asterisk_manager_check_connection();
#warning("== asterisk_manager_command START ==");
#warning(Dumper(%my_action));
        $asterisk_manager_response = $asterisk_manager_connection->action(\%my_action);
#warning(Dumper($asterisk_manager_response));
#warning("== asterisk_manager_command STOP ==");

}
sub asterisk_manager_command_simple() {
        local($cmd) =@_;
        local($tmp,$tmp1,$tmp2,$answer,%answer,%hash);
        %hash = ( Action => 'Command', Command => $cmd);
        $asterisk_manager_response = &asterisk_manager_command(%hash);
        %hash = %{$asterisk_manager_response};
        $tmp = join("\n",@{$hash{CMD}});
        return $tmp;
}
sub asterisk_manager_command_simple_as_array() {
        local($cmd) =@_;
        local($tmp,$tmp1,$tmp2,$answer,%answer,%hash,@out);
        %hash = ( Action => 'Command', Command => $cmd);
        $asterisk_manager_response = &asterisk_manager_command(%hash);
        %hash = %{$asterisk_manager_response};
        return @{$hash{CMD}};
}
#------------------------
#
#
#------------------------
# some lost things 
#------------------------
sub sql_to_hash_by_page(){
	#
	# basic, query sql database by page and put in hash
	# $data{DATA} is the same format as template loops. just drop DATA in the loop you want
	# remeber you NEED add " LIMIT #LIMIT1 , #LIMIT2" in your DATA query in order to limit page itens. 
	# 
	# her is a example how to query and add on template hash.
	# 
	#	==== CGI START ====
	#   %template_data = ();
	#	%users_list = &sql_to_hash_by_page((
	#		'sql_total'=>"SELECT count(*) FROM users ", 
	#		'sql_data'=>"SELECT id,name,phone FROM users ORDER BY date desc LIMIT #LIMIT1 , #LIMIT2 ",
	#		'sql_data_names'=>"user_id,user_name,user_phone",
	#		'page_now'=>$form{page_number},
	#		'page_size'=>5
	#	));
	#	if ($users_list{OK} eq 1){
	#		#
	#		# put DATA into users_list loop
	#	    $template_data{users_list_found}= 1;
	#		%{$template_data{users_list}}	= %{$users_list{DATA}};
	#		#
	#		# create loop with page info
	#		$template_data{users_list_page_min} = $users_list{page_min};
	#		$template_data{users_list_page_max} = $users_list{page_max};
	#		$template_data{users_list_page_now} = $users_list{page_now};
	#		$template_data{users_list_page_previous} = ($template_data{page_now} > $template_data{page_min}) ? $template_data{page_now}-1 : "";
	#		$template_data{users_list_page_next} = ($template_data{page_now} < $template_data{page_max}) ? $template_data{page_now}+1 : "";
	#		foreach $p ($users_list{page_min}..$users_list{page_max}) {
	#			$template_data{users_list_pages}{$p}{page} = $p;
	#			$template_data{users_list_pages}{$p}{selected} = ($p eq $t{thread_page}) ? 1 : 0;
	#		}
	#	}
	#    &template_print("template.html",%template_data);
	#	==== CGI STOP ====
	#
	#	==== TEMPLATE.HTML START ====
	#	<table>
	#	<TMPL_LOOP NAME="users_list">
	#		<tr>
	#		<td>%user_id%</td>
	#		<td>%user_name%</td>
	#		<td>%user_phone%</td>
	#		</tr>
	#	</TMPL_LOOP>
	#	</table>
	#	<br>
	#	Page %users_list_page_now% of %users_list_page_max%<br>
	#	Select page: 
	#	<TMPL_LOOP NAME="users_list_pages"><a href=?page_number=%page%>%page%</a>,</TMPL_LOOP>
	#	==== TEMPLATE.HTML STOP ====
	#
	local(%data) = @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2);
	#
	# pega page limits
	%hash = &database_select($data{sql_total});
	$data{count} 		= ($hash{OK} eq 1) ? &clean_int($hash{DATA}{0}{0}) : 0;
	$data{count}		= ($data{count} eq "") ? 0 : $data{count};
	$data{page_size}	= &clean_int($data{page_size});
	$data{page_size}	= ($data{page_size} eq "") ? $workgroup_config{page_size} : $data{page_size};
	$data{page_size}	= ($data{page_size} > 1024) ? 1024 : $data{page_size};
	$data{page_size}	= ($data{page_size} < 1 ) ? 1 : $data{page_size};
	$data{page_min}		= 1;
	$data{page_max}		= int(($data{count}-1)/$data{page_size})+1;
	$data{page_max}		= ($data{page_max}<$data{page_min}) ? $data{page_min} : $data{page_max};
	$data{page_now} 	= &clean_int($data{page_now});
	$data{page_now} 	= ($data{page_now}<$data{page_min}) ? $data{page_min} : $data{page_now};
	$data{page_now} 	= ($data{page_now}>$data{page_max}) ? $data{page_max} : $data{page_now};
	$data{sql_limit_1}	= ($data{page_now}-1)*$data{page_size};
	$data{sql_limit_2}	= $data{page_size};
	#
	# pega ids
	if ($data{count} > 0){
		$data{sql_data_run} = $data{sql_data};
		$tmp2=$data{sql_limit_1}; $tmp1="#LIMIT1"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		$tmp2=$data{sql_limit_2}; $tmp1="#LIMIT2"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		%hash = &database_select($data{sql_data_run},$data{sql_data_names});
		if ($hash{OK} eq 1) {
			%{$data{DATA}} = %{$hash{DATA}};
			$data{ROWS}	= $hash{ROWS};
			$data{COLS}	= $hash{COLS};
			$data{OK}	= 1;
		}
	}
	#
	# return
	return %data;
}
sub ip_flood_counter(){
	local ($section) = @_;
	local ($ip) = $ENV{REMOTE_ADDR};
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash,$counter_1,$counter_2,$timestamp);
	#
	# remember in runtime query
	if ($app{ip_flood_counter_ip} eq $ip){
		return ($app{ip_flood_counter_1},$app{ip_flood_counter_2})
	}
	# 
	# lets query and count
	$counter_1	= 0;
	$counter_2	= 0;
    %hash = &database_select_as_hash("SELECT 1,1,counter_1,counter_2,unix_timestamp(timestamp) FROM security_ip_flood where ip='$ip'","flag,counter_1,counter_2,timestamp");
	if ($hash{1}{flag} eq 1) {
		$counter_1	= ($hash{1}{counter_1}	ne "") ? $hash{1}{counter_1}: 1;
		$counter_2	= ($hash{1}{counter_2}	ne "") ? $hash{1}{counter_2}: 1;
		$timestamp	= ($hash{1}{timestamp}	ne "") ? $hash{1}{timestamp}: time;
		if ( (time-$timestamp)<(60) 	) {$counter_1++;} else {$counter_1 = 0;}
		if ( (time-$timestamp)<(60*10) 	) {$counter_2++;} else {$counter_2 = 0;}
		&database_do("
		update security_ip_flood set
		counter_1 = '$counter_1',
		counter_2 = '$counter_2',
		timestamp  = now()
		where ip='$ip'
		");
	} else {
		&database_do("
		insert into security_ip_flood
		(ip,     timestamp,  counter_1,   counter_2   ) values
		('$ip',  now(),      '1',         '1'         )
		");
		$counter_1	= 1;
		$counter_2	= 1;
	}
	$app{ip_flood_counter_ip} 	= $ip;
	$app{ip_flood_counter_1}	= $counter_1;
	$app{ip_flood_counter_2}	= $counter_2;
	return($counter_1,$counter_2);
}
sub ip_flood_surge_protection(){
	if ($ENV{REMOTE_ADDR} eq "127.0.0.1") {return}
	local ($section) = @_;
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash,$counter_1,$counter_2,$timestamp);
	($counter_1,$counter_2) = &ip_flood_counter();
	if ( ($counter_1 > 10) || ($counter_2 > 60) ) {
		&action_history("ipflood",('value_new'=>$ENV{REMOTE_ADDR}, 'value_old'=>"$section"  ));
		$buf = "";
		$buf .= "DATE $today{DATE_TO_PRINT} $today{TIME_TO_PRINT} \n";
		$buf .= "DATE_ID = $today{DATE_ID}$today{TIME_ID} \n";
		$buf .= "SECTION = $section \n";
		$buf .= "COUNTERS = $ip - $counter_1 - $counter_2\n";
		foreach(sort keys %form){$buf .= "FORM $_ = $form{$_}\n";}
		foreach(sort keys %ENV){
			if (index($_,"SSL_") eq 0) {next}
			if (index($_,"SERVER_") eq 0) {next}
			$buf .= "ENV $_ = $ENV{$_}\n";
		}
		open(LOG,">>$app_root/website/log/ip_flood.log");
		print LOG "\n\n$buf";
		close(LOG);
		print "Content-type: text/html\n";
		print "Cache-Control: no-cache, must-revalidate\n";
  		print "status:503\n";
		print "\n";
		print qq[
		<body bgcolor=#ffffff color=#000000 >
		<font face=verdana,arial size=2>
		<div 						style="padding:50px;">
		<div class=alert_box 		style="width:600px;padding:0px;margin:0px;border:1px solid #f8d322;background-color:#fff18e;">
		<div class=alert_box_inside	style="padding:0px;border:0px;margin-top:4px;margin-left:7px;margin-right:5px;margin-bottom:7px;padding-left:22px;padding-top:0px;background-image:url(/design/icons/forbidden.png);background-repeat:no-repeat;background-position:0 3;">
		<font size=3><b>Warning</b>:</font><br>
		You triggered website surge protection by doing too many requests in a short time.<br>
		Please make a short break, slow down and try again.<br>
		</div>
		</div>
		</div>
		];
		exit;
		#sleep(30);
		#When you restart doing requests AFTER that, slow down or you might get locked out for a longer time!<br>
	}
}
sub mobile_provider_send_sms(){
	local($provider_id,$number,$message) = @_;
	local ($email,%hash,$sql);
	$provider_id = &clean_int($provider_id);
	$sql = "SELECT 1,1,mobileProviderEmail FROM product_mobile_providers where mobileProviderID='$provider_id' ";
	%hash = database_select_as_hash($sql,"flag,domain");
	if ($hash{1}{flag} eq 1) {
		$email = &clean_int(&format_E164_number($number,"USA"))."\@".$hash{1}{domain};
		&send_email($email,$email,"",$message);
		return 1;
	} else {
		return 0;
	}
}
sub dial_and_play_code(){
	local($number,$code,$service_id) = @_;
	local($rate_id,%rate_data,$callback_queue_folder,$asterisk_string,$callback_file,$callback_file_buf,%my_timestamp,$timestamp_future,$cmd,$tmp);
	#
	# find rate table to use
	$rate_id = &data_get("system_config","rate","play_code");
	if ($rate_id eq "") {return 0;} # no rate, no dial
	#
	# get rate for number and dialstring
	%rate_data = &multilevel_rate_table_get($number,$rate_id);
	if ($rate_data{ok_to_use} ne 1) {return 0;} # no rate, no dial
	$asterisk_string = $rate_data{asterisk_string};
	#
	# prepare call file
	$callback_queue_folder	=  "/var/spool/asterisk/outgoing/";
	$callback_file			= time.$number.".sendcode.call"; 
	$callback_file_buf 		=  "Channel: $asterisk_string\n";
	$callback_file_buf 		.= "MaxRetries: 2\n";
	$callback_file_buf 		.= "RetryTime: 5\n";
	$callback_file_buf 		.= "WaitTime: 40\n";
	$callback_file_buf 		.= "Application: AGI\n";
	#$callback_file_buf 	.= "Data: play_code.pl|code=$code|\n";
	$callback_file_buf 		.= "Data: play_code.pl,code=$code\n";
	$callback_file_buf 		.= "AlwaysDelete:Yes\n";
	$callback_file_buf 		.= "Archive:No\n";
	#
	# write call file with 5 seconds in future (not state of art)
	%my_timestamp = &get_today(time+5);
	$timestamp_future = substr("0000".$my_timestamp{YEAR},-4,4) . substr("00".$my_timestamp{MONTH},-2,2) . substr("00".$my_timestamp{DAY},-2,2) . substr("00".$my_timestamp{HOUR},-2,2) . substr("00".$my_timestamp{MINUTE},-2,2) .".".substr("00".$my_timestamp{SECOND},-2,2);
	open (OUT,">/tmp/$callback_file");
	print OUT $callback_file_buf;
	close (OUT);
	$cmd = "chmod 666 /tmp/$callback_file; ";
	$cmd .= "touch -t $timestamp_future /tmp/$callback_file; ";
	$cmd .= "mv /tmp/$callback_file $callback_queue_folder; ";
	$tmp = `$cmd`;
	#
	# ok!
	return 1;
}
sub send_email(){
	local ($from,$to,$subject,$message,$has_head) = @_;
	local ($email_raw);
	$email_raw = "";
	$email_raw .= "from:$from\n";
	##$email_raw .= "To: $to\n";
	if (index("\U$message","SUBJECT:") eq -1) {$email_raw .= "Subject: $subject\n";}
	$email_raw .= "MIME-Version: 1.0\n";
	##$email_raw .= "Delivered-To: $to\n";
	if ($has_head ne 1) {$email_raw .= "\n";}
	$email_raw .= "$message\n";
	open(SENDMAIL,">>$app_root/website/log/send_email.log");
	print SENDMAIL  "\n";
	print SENDMAIL  "\n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "## NEW EMAIL TIME=(".time.") to=($to)\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL $email_raw;
	close(SENDMAIL);
	open(SENDMAIL, "|/usr/sbin/sendmail.postfix $to");
	print SENDMAIL $email_raw;
	close(SENDMAIL);
}
#------------------------
#
#------------------------
# log_debug api
#------------------------
sub log_debug_get(){
	local($ref_or_debug_id) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql,$out);
	local($buf,$debug_id);
	# 
	# check if we have a log_debug_id or ref and get log_debug_id if its a ref
	if ($ref_or_debug_id eq "") {return ""}
	if (&clean_int($ref_or_debug_id) eq $ref_or_debug_id) {
		$debug_id = $ref_or_debug_id
	} else {
		$debug_id = &log_debug_search_log_debug_id_by_ref($ref_or_debug_id);
	}
	if ($debug_id eq "") {return ""}
	#
	# get and retun text	
	$sql = &database_scape_sql("select 1,1,text from log_debug where id='%d' ",$debug_id);
	%hash =	database_select_as_hash($sql,"flag,text");
	return $hash{1}{text};
}
sub log_debug_add(){
	local($ref,%data) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql,$out);
	local($text,$debug_id);
	#
	# DISABLED
	return;
	#
	# hack: right now, to make fast, we always assume we got a hash
	# 
	# check if we have a hash or text. if hash, convert to text
	$text = &log_debug_convert_hash_to_text(%data);
	#
	# add text to database and get id
	$sql = &database_scape_sql("insert into log_debug (date,text) values (now(),\"%s\")",$text);
	$debug_id = &database_do_insert($sql);
	if ($debug_id eq "") {return ""}
	#
	# add each reference to ref table
	foreach $tmp (split(/\,/,$ref)){
		$tmp = &trim($tmp);
		($tmp1,$tmp2) = split(/\=/,$tmp);
		$tmp1 = &trim($tmp1);
		$tmp2 = &trim($tmp2);
		$tmp1 = "\L$tmp1";
		$sql = &database_scape_sql("insert into log_debug_reference (log_debug_id,reference_name,reference_value) values ('%d','%s','%s')",$debug_id,$tmp1,$tmp2);
		&database_do($sql);
	}
	#
	# return
	return $debug_id;
}
sub log_debug_convert_hash_to_text(){
	local(%hash) = @_;
	local($buf);
	$buf = "";
	foreach (sort keys %hash) {
		if ($_ eq "debug") {next} 
		if ($_ eq "cc_number") {$hash{$_} = substr($hash{$_},-4,4);} 
		$buf .= "$_ = $hash{$_}\n";
	}
	foreach (split(/\!/,$hash{debug})) {$buf .= "debug = $_\n";}
	return $buf;
}
sub log_debug_convert_hash_to_array(){
	local(%hash) = @_;
	local(@buf);
	$buf = "";
	foreach (sort keys %hash) {if ($_ eq "debug") {next} @buf = (@buf,"$_ = $hash{$_}");}
	foreach (split(/\!/,$hash{debug})) { @buf = (@buf,"debug = $_");}
	return @buf;
}
sub log_debug_search_log_debug_id_by_ref(){
	local($ref) = @_;
	local(%hash,$sql,$tmp,$tmp1,$tmp2,$sql,$out);
	local($ref_name,$ref_value);
	($ref_name,$ref_value) = split(/\=/,$ref);
	$sql = &database_scape_sql(
		"
		select 1,1,log_debug_id 
		from log_debug_reference 
		where reference_name='%s' and reference_value='%s' 
		order by id desc
		limit 0,1 
		",
		$ref_name,$ref_value
	);
	%hash =	database_select_as_hash($sql,"flag,value");
	if ($hash{1}{flag} eq 1) {
		return $hash{1}{value};
	}
	return "";
}
#------------------------
#
#------------------------
# action_history
#------------------------
sub action_history_get_info(){
	local($log_ids,$flags) = @_;
	local(%out,$sql,$tmp,$tmp1,$tmp2,%hash,%logs,$icon,$title,$text,$user,%adm_users,$by,%extra);
	$flags = "\L$flags";
	$flags = "\Lno_user,no_date";
	#
	# prepara lista de logs a se verificar
	$sql = "
		SELECT
			system_action_log.id,
			unix_timestamp(system_action_log.date),
			system_action_log.type,
			system_action_log_type.group,
			system_action_log_type.title,
			system_action_log_type.description,
			system_action_log.value_old,
			system_action_log.value_new,
			system_action_log.adm_user_id,
			system_action_log.call_log_id,
			system_action_log.service_id,
			system_action_log.credit_id,
			system_action_log.commission_id,
			system_action_log.commission_invoice_id
		FROM
			system_action_log,
			system_action_log_type
		WHERE
			system_action_log.id in ($log_ids) and
			system_action_log.type=system_action_log_type.id
	";
	%logs = database_select_as_hash($sql, "date,type,group,title,description,value_old,value_new,adm_user_id,call_debug_id,service_id,credit_id,commission_id,commission_invoice_id,coupon_stock_id,cupon_type_id");
    %adm_users = database_select_as_hash("select id,web_user,name from $app{users_table}","web_user,name");
	#
	# pega lista de ids de tabelas de juda
	foreach $log_id (keys %logs) {
		if ($logs{$log_id}{credit_id} ne "") {$extra{credit}{ids} .= "$logs{$log_id}{credit_id},"}
	}
	if ($extra{credit}{ids} ne "") {
		$extra{credit}{ids} = substr($extra{credit}{ids},0,-1);
	    %hash = database_select_as_hash("select id,credit,text from credit where id in($extra{credit}{ids}) ","credit,text");
		$extra{credit}{id} = {%hash};
	}
	#
	# monta a saida
	foreach $log_id (keys %logs) {
		$user 	= (exists($adm_users{$logs{$log_id}{adm_user_id}})) ? "$adm_users{$logs{$log_id}{adm_user_id}}{web_user} ($adm_users{$logs{$log_id}{adm_user_id}}{name})" : "";
		$by		= ($user eq "") ? "" : "by $user";
		$out{$log_id}{icon} 			= "application_go.png";
		$out{$log_id}{title_full} 		= "$logs{$log_id}{group} : $logs{$log_id}{title}";
		$out{$log_id}{title} 			= $logs{$log_id}{title};
		$out{$log_id}{group} 			= $logs{$log_id}{group};
		$out{$log_id}{text} 			= $logs{$log_id}{title};
		if ($logs{$log_id}{description} ne ""){
			$out{$log_id}{text} = $logs{$log_id}{description};
			$tmp1="#1"; $tmp2=$logs{$log_id}{value_old}; $out{$log_id}{text} =~ s/$tmp1/$tmp2/eg;
			$tmp1="#2"; $tmp2=$logs{$log_id}{value_new}; $out{$log_id}{text} =~ s/$tmp1/$tmp2/eg;
		} else {
			$tmp = "";
			$tmp .= ($logs{$log_id}{value_old} ne "") ? "'$logs{$log_id}{value_old}' " : "";
			$tmp .= ($logs{$log_id}{value_new} ne "") ? "'$logs{$log_id}{value_new}'" : "";
			$out{$log_id}{text} .= ($tmp eq "") ? "" : " (data $tmp)";
		}
		$out{$log_id}{text_long} 		= $out{$log_id}{text};
		$out{$log_id}{text_simple} 		= $out{$log_id}{text};
		$out{$log_id}{text_extra} 		= $out{$log_id}{text};
		$out{$log_id}{date} 			= &format_time_gap($logs{$log_id}{date});
		$out{$log_id}{date_timestamp} 	= $logs{$log_id}{date};
		$out{$log_id}{user} 			= $user;
		$out{$log_id}{by} 				= $by;
		$out{$log_id}{detail} 			= 0;
	}
	#
	# return
	return %out;
}
sub action_history(){
	local($id,%data) = @_;
	local($out,$sql,$tmp,$names,$values);
	$names = "";
	$values= "";
	foreach $tmp (("coupon_stock_id","coupon_type_id","value_new","value_old","service_id","signin_id","adm_user_id","credit_id","commission_id","call_log_id","commission_invoice_id")){
		if (exists($data{$tmp})){
			if ($data{$tmp} ne ""){
				$names  .= "$tmp, ";
				$values .= "'$data{$tmp}', ";
			}
		}
	}
	# TODO: add adm user id automatic
	if ($data{adm_user_id} eq "") {
		if ($app{session_cookie_u} ne "") {
			if ($app{users_table} eq "system_user"){
				$names  .= "adm_user_id, ";
				$values .= "'$app{session_cookie_u}', ";
			}
		}
	}
	$sql = "insert system_action_log (date, $names type) values (now(), $values '$id' ) ";
	# adiciona
	database_do($sql);
}
#------------------------

#
#------------------------
# clickchain (protect from url forge)
#------------------------
sub clickchain_set(){
	local ($prefix) = @_;
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash);
	$out = substr($prefix,0,2).time;
	$tmp = &active_session_get("clickchain");
	&active_session_set("clickchain",substr("$out,$tmp",0,200));
	return $out;
}
sub clickchain_check(){
	local ($prefix,$id) = @_;
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash,$in);
	$in = substr($prefix,0,2).&clean_int($id);
	if ($in eq "") {return 0}
	$buf = &active_session_get("clickchain");
	$tmp = ",$buf,";
	$tmp1 = ",$in,";$tmp2 = ",";	$tmp =~ s/$tmp1/$tmp2/eg;
	$tmp1 = ",,";	$tmp2 = ",";	$tmp =~ s/$tmp1/$tmp2/eg;
	$tmp1 = ",,";	$tmp2 = ",";	$tmp =~ s/$tmp1/$tmp2/eg;
	&active_session_set("clickchain",substr($tmp,0,200));
	if (index(",$buf,",",$in,") ne -1) {return 1}
	return 0;
}
#
#------------------------
# data item
#------------------------
sub dataitem_initialize(){
	my $d = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	#
	# load slect with sql fields
	foreach $i (keys %{$$d{config}{items}}) {
		if ($$d{config}{items}{$i}{type} eq "SELECT") {	
			if ($$d{config}{items}{$i}{options_sql} ne "") {	
				$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{options_sql},('KEY'=>$$d{data}{key}));
				%hash = database_select($sql);
				%{$$d{config}{items}{$i}{options}} = ();
				foreach $tmp (sort{$a <=> $b} keys %{$hash{DATA}}){
					$$d{config}{items}{$i}{options}{$tmp}{value}	= $hash{DATA}{$tmp}{0};
					$$d{config}{items}{$i}{options}{$tmp}{title}	= $hash{DATA}{$tmp}{1};
				}
			}
		}
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
			if ($$d{config}{items}{$i}{options_sql} ne "") {	
				$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{options_sql},('KEY'=>$$d{data}{key}));
				%hash = database_select($sql);
				%{$$d{config}{items}{$i}{options}} = ();
				foreach $tmp (sort{$a <=> $b} keys %{$hash{DATA}}){
					$$d{config}{items}{$i}{options}{$tmp}{value}	= $hash{DATA}{$tmp}{0};
					$$d{config}{items}{$i}{options}{$tmp}{title}	= $hash{DATA}{$tmp}{1};
				}
			}
		}
	}
	return 1;
}
sub dataitem_add(){
	my $d = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	#
	# check basic
	if ($$d{config}{sql_add} 	eq "")	{$$d{status_message} = "No sql_add"; 	return 0;}
	#
	# check if key exists
	if ($$d{config}{key_mode} eq "MANUAL") {
		$tmp1 = $$d{config}{key_item};
		$tmp2 = $$d{data}{items}{$tmp1}{value};
		if ($tmp2 eq "")	{$$d{status_message} = "No manual key to check duplicate"; return 0;}
		$sql = &dataitem_tools_sql_parse($$d{config}{key_duplicate_sql},('KEY'=>$tmp2,'VALUE'=>$tmp2));
		%hash = database_select($sql);
		if ($hash{DATA}{0}{0} eq 1)	{$$d{status_message} = "duplicate key"; return 0;}
	}
	#
	# add data
	if ($$d{config}{key_mode} eq "MANUAL") {
		$tmp1 = $$d{config}{key_item};
		$tmp2 = $$d{data}{items}{$tmp1}{value};
		if ($tmp2 eq "")	{$$d{status_message} = "No manual key to add"; return 0;}
		$$d{data}{key} = $tmp2;
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_add},('KEY'=>$tmp2,'VALUE'=>$tmp2));
		&database_do($sql);
	} else {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_add});
		$$d{data}{key} = &database_do_insert($sql);
	}
	#
	# update data
	&dataitem_set($d);
	#
	# return
	return 1;
}
sub dataitem_get(){
	my $d = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	#
	# check basic
	if ($$d{config}{sql_key} 	eq "")	{$$d{status_message} = "No sql_key"; 	return 0;}
	if ($$d{data}{key} 			eq "")	{$$d{status_message} = "No key"; 		return 0;}
	#
	# check if key exists
	$sql = &dataitem_tools_sql_parse($$d{config}{sql_key},('KEY'=>$$d{data}{key}));
	%hash = database_select($sql);
	if ($hash{DATA}{0}{0} ne 1)			{$$d{status_message} = "key not found"; return 0;}
	#
	# load all fields
	foreach $i (keys %{$$d{config}{items}}) {
		if ($$d{config}{items}{$i}{sql_get} eq "") {next}
		if ($$d{config}{items}{$i}{type} eq "NUMBER") {	
			$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key}));
			%hash = database_select($sql);
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "STRING") {	
			$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key}));
			%hash = database_select($sql);
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "SELECT") {	
			$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key}));
			%hash = database_select($sql);
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
			foreach $tmp (keys %{$$d{config}{items}{$i}{options}}) {
				$tmp1 = $$d{config}{items}{$i}{options}{$tmp}{value};
				$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key},'OPTIONID'=>$tmp1));
				%hash = database_select($sql);
				if ($hash{DATA}{0}{0} eq 1) {
					$$d{data}{items}{$i}{value} .= ($$d{data}{items}{$i}{value} ne "") ? ",$tmp1" : $tmp1;
				}
			}
		}
		#
		# default value
		if ($$d{data}{items}{$i}{value} eq "") {
			if (index("\U,$$d{config}{items}{$i}{flags},",",USE_DEFAULT_VALUE_IF_EMPTY,") ne -1) {
				$$d{data}{items}{$i}{value} = $$d{config}{items}{$i}{default_value};
			}
		}
	}
	#
	# return
	$$d{status_message} = "OK"; 
	return 1;
}
sub dataitem_set(){
	my $d = shift @_;
	local($sql,%hash,$value,$i,$tmp,$tmp1,$tmp2);
	#
	# check basic
	if ($$d{config}{sql_key} 	eq "")	{$$d{status_message} = "No sql_key"; 	return 0;}
	if ($$d{data}{key} 			eq "")	{$$d{status_message} = "No key"; 		return 0;}
	#
	# check if key exists
	$sql = &dataitem_tools_sql_parse($$d{config}{sql_key},('KEY'=>$$d{data}{key}));
	%hash = database_select($sql);
	if ($hash{DATA}{0}{0} ne 1)			{$$d{status_message} = "key not found"; return 0;}
	#
	# update all fields
	foreach $i (keys %{$$d{config}{items}}) {
		if ($$d{config}{items}{$i}{sql_set} eq "") {next}
		if ($$d{config}{items}{$i}{sql_get} eq "") {next}
		if ( (index("\U,$$d{config}{items}{$i}{flags},",",ONLY_SET_IF_NOT_EMPTY,") ne -1) && ($$d{data}{items}{$i}{value} eq "") ) {next}
		#
		# default value
		if ($$d{data}{items}{$i}{value} eq "") {
			if (index("\U,$$d{config}{items}{$i}{flags},",",USE_DEFAULT_VALUE_IF_EMPTY,") ne -1) {
				$$d{data}{items}{$i}{value} = $$d{config}{items}{$i}{default_value};
			}
		}
		#
		# run sql_before_set
		if ($$d{config}{items}{$i}{sql_before_set} ne "") {
			$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_before_set},('KEY'=>$$d{data}{key}));
			database_do($sql);
		}
		#
		# set
		if ($$d{config}{items}{$i}{type} eq "STRING") {	
			$tmp1 = $$d{config}{items}{$i}{sql_set};   if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_1}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_2}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_3}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_4}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_5}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$$d{data}{items}{$i}{value})); &database_do($sql);}
			%hash = database_select(&dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key})));
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "NUMBER") {	
			$tmp2 = ($$d{data}{items}{$i}{value} eq "") ? "NULL" : $$d{data}{items}{$i}{value};
			$tmp1 = $$d{config}{items}{$i}{sql_set};   if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_1}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_2}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_3}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_4}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_5}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			%hash = database_select(&dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key})));
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "SELECT") {	
			$tmp2 = ($$d{data}{items}{$i}{value} eq "") ? "NULL" : $$d{data}{items}{$i}{value};
			$tmp1 = $$d{config}{items}{$i}{sql_set};   if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_1}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_2}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_3}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_4}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			$tmp1 = $$d{config}{items}{$i}{sql_set_5}; if ($tmp1 ne "") {$sql = &dataitem_tools_sql_parse($tmp1,('KEY'=>$$d{data}{key},'VALUE'=>$tmp2)); &database_do($sql);}
			%hash = database_select(&dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_get},('KEY'=>$$d{data}{key})));
			$$d{data}{items}{$i}{value} = $hash{DATA}{0}{0};
		}
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
			# run set/unset for each item
			foreach $tmp (keys %{$$d{config}{items}{$i}{options}}) {
				$tmp1 = $$d{config}{items}{$i}{options}{$tmp}{value};
				if (index(",$$d{data}{items}{$i}{value},",",$tmp1,") ne -1) {
					if ($$d{config}{items}{$i}{sql_set} ne "") {
	 					$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_set},('KEY'=>$$d{data}{key},'OPTIONID'=>$tmp1));
	 					database_do($sql);
					}
				} else {
					if ($$d{config}{items}{$i}{sql_unset} ne "") {
	 					$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_unset},('KEY'=>$$d{data}{key},'OPTIONID'=>$tmp1));
	 					database_do($sql);
					}
				}
			}
		}
		#
		# run sql_after_set
		if ($$d{config}{items}{$i}{sql_after_set} ne "") {
			$sql = &dataitem_tools_sql_parse($$d{config}{items}{$i}{sql_after_set},('KEY'=>$$d{data}{key}));
			database_do($sql);
		}
	}
	# 
	# update dataitem
	if ($$d{config}{sql_edit} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_edit},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	#
	# return
	$$d{status_message} = "OK"; 
	return 1;
}
sub dataitem_del(){
	my $d = shift @_;
	local($sql,%hash,$value,$i,$tmp,$tmp1,$tmp2);
	#
	# check basic
	if ($$d{config}{sql_key} 	eq "")	{$$d{status_message} = "No sql_key"; 	return 0;}
	if ($$d{config}{sql_del} 	eq "")	{$$d{status_message} = "No sql_del"; 	return 0;}
	if ($$d{data}{key} 			eq "")	{$$d{status_message} = "No key"; 		return 0;}
	#
	# check if key exists
	$sql = &dataitem_tools_sql_parse($$d{config}{sql_key},('KEY'=>$$d{data}{key}));
	%hash = database_select($sql);
	if ($hash{DATA}{0}{0} ne 1)			{$$d{status_message} = "key not found"; return 0;}
	#
	# delete
	if ($$d{config}{sql_del} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_1} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_1},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_2} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_2},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_3} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_3},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_4} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_4},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_5} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_5},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_6} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_6},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_7} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_7},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_8} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_8},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	if ($$d{config}{sql_del_9} ne "") {
		$sql = &dataitem_tools_sql_parse($$d{config}{sql_del_9},('KEY'=>$$d{data}{key}));
		&database_do($sql);
	}
	#
	# return
	$$d{status_message} = "OK"; 
	return 1;
}
sub dataitem_tools_sql_parse(){
	local($sql,%dic) = @_;
	local(%hash,$i,$tmp,$tmp1,$tmp2);
	foreach $tmp1 (keys %dic){
		$tmp2	= "'".$dic{$tmp1}."'";
		if ($tmp2 eq "'NULL'") {
			$tmp2	= "NULL";
		}
		$tmp1	= "\U$tmp1";
		$tmp1	= "#$tmp1#";
		$sql	=~ s/$tmp1/$tmp2/eg;
	}
	return $sql;
}
sub dataitem_web_data2form(){ 
	my $d = shift @_;
	my $f = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	foreach $i (keys %{$$d{config}{items}}) {
		if ($$d{config}{items}{$i}{type} eq "NUMBER") {	
			$$f{"data$i"} = $$d{data}{items}{$i}{value}; 
		}
		if ($$d{config}{items}{$i}{type} eq "STRING") {	
			$$f{"data$i"} = $$d{data}{items}{$i}{value}; 
		}
		if ($$d{config}{items}{$i}{type} eq "SELECT") {	
			$$f{"data$i"} = $$d{data}{items}{$i}{value}; 
		}
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
			$$f{"data$i"} = $$d{data}{items}{$i}{value}; 
		}
	}
	return 1;
}
sub dataitem_web_form2data(){
	my $d = shift @_;
	my $f = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	foreach $i (keys %{$$d{config}{items}}) {
		if (index("\U,$$d{config}{items}{$i}{flags},",",UI_READONLY,") ne -1) {next}
		if ($$d{config}{items}{$i}{type} eq "NUMBER") 		{	$$d{data}{items}{$i}{value} = $$f{"data".$i}; }
		if ($$d{config}{items}{$i}{type} eq "STRING") 		{	$$d{data}{items}{$i}{value} = $$f{"data".$i}; }
		if ($$d{config}{items}{$i}{type} eq "SELECT") 		{	$$d{data}{items}{$i}{value} = $$f{"data".$i}; }
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") 	{	$$d{data}{items}{$i}{value} = $$f{"data".$i}; }
	}
	return 1;
}
sub dataitem_web_formcheck(){ 
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
	$$d{data}{form_error} = 0;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2,$need_test);
	foreach $i (keys %{$$d{config}{items}}) {
		#
		# do we need check this item?
		$need_test = 1;
		$need_test = ($$d{config}{items}{$i}{sql_set} eq "") ? 0 : $need_test;
		$need_test = ( ($$fs{mode} eq "ADD") && ($$d{config}{key_mode} eq "MANUAL") && ($$d{config}{key_item} eq $i) )  ? 1 : $need_test;
		$need_test = (index("\U,$$d{config}{items}{$i}{flags},",",UI_READONLY,") ne -1) ? 0 : $need_test ;
		if ($need_test ne 1) {next}
		#
		# check integer
		if ($$d{config}{items}{$i}{type} eq "NUMBER") {	
			$tmp1 = trim(substr($$f{"data$i"},0,100));
			#$tmp = clean_int($tmp1); 
			$tmp = clean_str($tmp1); 
			$tmp++;
			$tmp--;
			#if ( ($tmp1 ne $tmp) || ($tmp eq "") || ($tmp1 eq "") ) {
			if ( ($tmp eq "") || ($tmp1 eq "") ) {
				if ( index(",".$$d{config}{items}{$i}{flags}."," , ",ALLOW_EMPTY,") eq -1) {
					$$d{data}{items}{$i}{form_error} = 1;
					$$d{data}{form_error}= 1;
				}
			} else {
				if (exists($$d{config}{items}{$i}{min})) {
					if ($tmp < $$d{config}{items}{$i}{min}){
						$$d{data}{items}{$i}{form_error} = 1;
						$$d{data}{form_error}= 1;
					}
				}
				if (exists($$d{config}{items}{$i}{max})) {
					if ($tmp > $$d{config}{items}{$i}{max}){
						$$d{data}{items}{$i}{form_error} = 1;
						$$d{data}{form_error}= 1;
					}
				}
			}
		}
		#
		# check string
		if ($$d{config}{items}{$i}{type} eq "STRING") {	
			$tmp = trim($$f{"data$i"}); 
			if ($tmp eq "") {
				if ( index(",".$$d{config}{items}{$i}{flags}."," , ",ALLOW_EMPTY,") eq -1) {
					$$d{data}{items}{$i}{form_error} = 1;
					$$d{data}{form_error}= 1;
				}
			}
		}
		#
		# check select
		if ($$d{config}{items}{$i}{type} eq "SELECT") {	
			$tmp1 = trim($$f{"data$i"}); 
			$tmp2 = "|";
			foreach $tmp (keys %{$$d{config}{items}{$i}{options}}) { $tmp2 .= $$d{config}{items}{$i}{options}{$tmp}{value}."|"; }
			if ($tmp1 eq "") {
				if ( index(",".$$d{config}{items}{$i}{flags}."," , ",ALLOW_EMPTY,") eq -1) {
					$$d{data}{items}{$i}{form_error} = 1;
					$$d{data}{form_error}= 1;
				}
			} else {
				if ( ($tmp1 eq "") || (index($tmp2,"|$tmp1|") eq -1) ) {
					$$d{data}{items}{$i}{form_error} = 1;
					$$d{data}{form_error}= 1;
				}
			}
		}
		#
		# check multiselect
		if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
		}
	}
	return ($$d{data}{form_error} eq 0) ? 1 : 0;
}
sub dataitem_web_editform_process(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
    $$fs{status_ok}			= 0;
    $$fs{status_error}		= 0;
    $$fs{status_message}	= "";
    if ($$f{saveid} eq "") {
    	&dataitem_web_data2form($d,$f);
    } else {
	    if (&clickchain_check($$fs{click_id_prefix},$$f{saveid}) eq 1) {
			if (&dataitem_web_formcheck($d,$fs,$f)) {
		    	&dataitem_web_form2data($d,$f);
				&dataitem_set($d);
			    $$fs{status_ok}			= 1;
			    $$fs{status_error}		= 0;
			    $$fs{status_message}	= "";
			    if (index(",$$fs{flags},",",REDIRECT_IF_OK,") ne -1) {
					cgi_redirect($$fs{url_form_ok});
					exit;
			    }
			    return 1;
			} else {
			    $$fs{status_ok}			= 0;
			    $$fs{status_error}		= 1;
			    $$fs{status_message}	= "I cannot save. Please check errors and try again.";
			}
	    } else {
		    $$fs{status_ok}			= 0;
		    $$fs{status_error}		= 1;
		    $$fs{status_message}	= "I cannot save. Please check errors and try again.";
	    }
    }
	return 0;
}
sub dataitem_web_editform_gethtml(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	local($save_id,$form_message,$html,$form_hidden_elements);
    $save_id = &clickchain_set($$fs{click_id_prefix});
    $form_message = ($$fs{status_message} ne "") ? "<div class=alert_box><div class=alert_box_inside>$$fs{status_message}</div></div><br>" : "";
    $html	= qq[
    	<form class=dataitemform  action='$$fs{url_form_action}' method=post >
   		<table class=clear border=0 colspan=0 cellpadding=2 cellspacing=0 >
    ];
	foreach $i (sort{$a <=> $b} keys %{$$d{config}{items}}) {
		#
		# if item its read only, disable and because its disabled, always populate form with real data
		$item_value 	= $$f{"data$i"};
		$item_disabled 	= "";
		$item_value 	= ($$d{config}{items}{$i}{sql_set} eq "") ? $$d{data}{items}{$i}{value} : $item_value;
		$item_disabled 	= ($$d{config}{items}{$i}{sql_set} eq "") ? " read-only disabled ": $item_disabled; 
		$item_disabled	= (index("\U,$$d{config}{items}{$i}{flags},",",UI_READONLY,") ne -1) ? " read-only disabled " : $item_disabled;
		#
		# print group user interface
		if ($$d{config}{items}{$i}{group} ne "") {
		    $html .= qq[
	    	<tr>
	    	<td valign=top colspan=2><br><h1>$$d{config}{items}{$i}{group}</h1><hr></td>
	    	</tr>
		    ];
		}
		#
		# prepare to draw object in html
		if (index("\U,$$d{config}{items}{$i}{flags},",",UI_HIDDEN,") ne -1) {
			#
			# hide this guy
			#$html .= "<tr><td colspan=2>hidden $$d{config}{items}{$i}{title}: ";
			$html .= "<input type=hidden name='data$i' value='$item_value'>";
			#$html .= "</td></tr> ";
		} else {
			# 
			# we need html to draw this guy
			if ($$d{config}{items}{$i}{type} eq "NUMBER") {
				if ($$d{data}{items}{$i}{form_error} eq 1) {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i style='border:1px solid red;' value='$item_value' ><br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font></td>
			    	</tr>
				    ];
				} else {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i value='$item_value' > </td>
			    	</tr>
				    ];
				}
			}
			if ($$d{config}{items}{$i}{type} eq "STRING") {	
				if ($$d{data}{items}{$i}{form_error} eq 1) {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i style='border:1px solid red;' value='$item_value' ><br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font></td>
			    	</tr>
				    ];
				} else {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i value='$item_value' > </td>
			    	</tr>
				    ];
				}
			}
			if ($$d{config}{items}{$i}{type} eq "SELECT") {	
				$tmp4 = ($$d{data}{items}{$i}{form_error} eq 1) ? "border:1px solid red;" : "";
				$tmp5 = ($$d{data}{items}{$i}{form_error} eq 1) ? "<br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font>" : "";
				$tmp6 = "";
				foreach $tmp (sort{$a <=> $b} keys %{$$d{config}{items}{$i}{options}}) {
					$tmp1 = $$d{config}{items}{$i}{options}{$tmp}{value};
					$tmp2 = $$d{config}{items}{$i}{options}{$tmp}{title};
					$tmp3 = ($item_value eq $tmp1) ? " selected " : "";
					$tmp6 .= "<option $tmp3 value='$tmp1'>$tmp2</option>";
				}
				$tmp7 = (exists($$d{config}{items}{$i}{options_first})) ? "<option value=''>$$d{config}{items}{$i}{options_first}</option>" : "";
			    $html .= qq[
		    	<tr>
		    		<td valign=top>$$d{config}{items}{$i}{title}</td>
		    		<td valign=top>
		    			<select $item_disabled name=data$i style='$tmp4' >
		    			$tmp7
						<option value=''>&nbsp;</option>
		    			$tmp6
		    			</select>
		    			$tmp5
					</td>
		    	</tr>
			    ];
			}
			if ($$d{config}{items}{$i}{type} eq "MULTISELECT") {	
				$tmp4 = ($$d{data}{items}{$i}{form_error} eq 1) ? "border:1px solid red;" : "";
				$tmp5 = ($$d{data}{items}{$i}{form_error} eq 1) ? "<br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font>" : "";
				$tmp6 = "";
				foreach $tmp (sort{$a <=> $b} keys %{$$d{config}{items}{$i}{options}}) {
					$tmp1 = $$d{config}{items}{$i}{options}{$tmp}{value};
					$tmp2 = $$d{config}{items}{$i}{options}{$tmp}{title};
					$tmp3 = (index(",$item_value,",",$tmp1,") ne -1)  ? " selected " : "";
					$tmp6 .= "<option  $tmp3 value='$tmp1'>$tmp2</option>";
				}
			    $html .= qq[
		    	<tr>
		    		<td valign=top>$$d{config}{items}{$i}{title}</td>
		    		<td valign=top>
		    			<select $item_disabled MULTIPLE size=4 name=data$i style='$tmp4' >
		    			$tmp6
		    			</select>
		    			$tmp5
					</td>
		    	</tr>
			    ];
			}
		}
	}
	#
	# add extra itens in this form
	$form_hidden_elements = "";
	foreach $i (sort{$a <=> $b} keys %{$$fs{hidden_elements}}) {
		$form_hidden_elements .= "<input type=hidden name='$$fs{hidden_elements}{$i}{name}' value='$$fs{hidden_elements}{$i}{value}'>";
	}
	#
	# draw buttons
	$tmp_1 = ($$fs{url_button_delete} eq "") ? "" : "<button class=delete type=button onclick=\"window.location='$$fs{url_button_delete}'\">Delete</button>";
    $html	.= qq[
		</table>
    	<br>
    	$form_message 
    	<button class=cancel type=button onclick="window.location='$$fs{url_button_cancel}'">Cancel</button>
    	$tmp_1
    	<button class=save type=submit>Save</button>
    	$form_hidden_elements
    	<input type=hidden name=key value='$$d{data}{key}'>
    	<input type=hidden name=saveid value='$save_id'>
    </form>
    ];
	return $html;
}
sub dataitem_web_deleteform_process(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
    $$fs{status_ok}			= 0;
    $$fs{status_error}		= 0;
    $$fs{status_message}	= "";
    if ($$f{saveid} ne "") {
	    if (&clickchain_check($$fs{click_id_prefix},$$f{saveid}) eq 1) {
			&dataitem_del($d);
			$$fs{status_ok}			= 1;
			$$fs{status_error}		= 0;
			$$fs{status_message}	= "";
			if (index(",$$fs{flags},",",REDIRECT_IF_OK,") ne -1) {
				cgi_redirect($$fs{url_form_ok});
				exit;
			}
		    return 1;
	    } else {
		    $$fs{status_ok}			= 0;
		    $$fs{status_error}		= 1;
		    $$fs{status_message}	= "I cannot save. Please check errors and try again.";
	    }
    }
	return 0;
}
sub dataitem_web_deleteform_gethtml(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	local($save_id,$form_message,$html,$form_hidden_elements);
    $save_id = &clickchain_set($$fs{click_id_prefix});
    $form_message = ($$fs{status_message} ne "") ? "<div class=alert_box><div class=alert_box_inside>$$fs{status_message}</div></div><br>" : "";
	$form_hidden_elements = "";
	foreach $i (sort{$a <=> $b} keys %{$$fs{hidden_elements}}) {
		$form_hidden_elements .= "<input type=hidden name='$$fs{hidden_elements}{$i}{name}' value='$$fs{hidden_elements}{$i}{value}'>";
	}
    $html	= qq[
    	<form action='$$fs{url_form_action}' method=post >
		$$fs{message}
    	<br>
    	<br>
    	$form_message 
    	<button class=cancel type=button onclick="window.location='$$fs{url_button_cancel}'">Cancel</button>
    	<button class=save type=submit>Delete</button>
    	$form_hidden_elements
    	<input type=hidden name=key value='$$d{data}{key}'>
    	<input type=hidden name=saveid value='$save_id'>
    </form>
    ];
	return $html;
}
sub dataitem_web_addform_process(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
    $$fs{status_ok}			= 0;
    $$fs{status_error}		= 0;
    $$fs{status_message}	= "";
    if ($$f{saveid} eq "") {
    	&dataitem_web_data2form($d,$f);
    } else {
	    if (&clickchain_check($$fs{click_id_prefix},$$f{saveid}) eq 1) {
	    	# 
	    	# save id is ok, lets check form basic data
			if (&dataitem_web_formcheck($d,$fs,$f)) {
				#
				# form data its ok, lets check manual key
				if ( ($$fs{mode} eq "ADD") && ($$d{config}{key_mode} eq "MANUAL") ) {
					$tmp1 = $$f{"data$$d{config}{key_item}"};
					$sql = &dataitem_tools_sql_parse($$d{config}{key_duplicate_sql},('KEY'=>$tmp1,'VALUE'=>$tmp1));
					%hash = database_select($sql);
					if ($hash{DATA}{0}{0} eq 1)	{
					    $$fs{status_ok}			= 0;
					    $$fs{status_error}		= 1;
					    $$fs{status_message}	= $$d{config}{key_duplicate_message};
					}
				}
				#
				# if all ok, do the action
				if ($$fs{status_error} eq 0) {
			    	&dataitem_web_form2data($d,$f);
					$tmp = &dataitem_add($d);
				    $$fs{status_ok}			= 1;
				    $$fs{status_error}		= 0;
				    $$fs{status_message}	= "";
				    if (index(",$$fs{flags},",",REDIRECT_IF_OK,") ne -1) {
						cgi_redirect($$fs{url_form_ok});
						exit;
				    }
				    return 1;
				}
			} else {
			    $$fs{status_ok}			= 0;
			    $$fs{status_error}		= 1;
			    $$fs{status_message}	= "I cannot save. Please check errors and try again.";
			}
	    } else {
		    $$fs{status_ok}			= 0;
		    $$fs{status_error}		= 1;
		    $$fs{status_message}	= "I cannot save. Please check errors and try again.";
	    }
    }
	return 0;
}
sub dataitem_web_addform_gethtml(){
	my $d  = shift @_;
	my $fs = shift @_;
	my $f  = shift @_;
	local($sql,%hash,$i,$tmp,$tmp1,$tmp2);
	local($save_id,$form_message,$html,$form_hidden_elements);
    $save_id = &clickchain_set($$fs{click_id_prefix});
    $form_message = ($$fs{status_message} ne "") ? "<div class=alert_box><div class=alert_box_inside>$$fs{status_message}</div></div><br>" : "";
    $html	= qq[
    	<form action='$$fs{url_form_action}' class=dataitemform method=post >
   		<table class=clear border=0 colspan=0 cellpadding=2 cellspacing=0 >
    ];
	foreach $i (sort{$a <=> $b} keys %{$$d{config}{items}}) {
		$item_value 	= ($$d{config}{items}{$i}{sql_set} eq "") ? $$d{data}{items}{$i}{value} : $$f{"data$i"};
		$item_disabled 	= ($$d{config}{items}{$i}{sql_set} eq "") ? " read-only disabled ": ""; 
		$item_disabled	= ( ($$fs{mode} eq "ADD") && ($$d{config}{key_mode} eq "MANUAL") && ($$d{config}{key_item} eq $i) )  ? "" : $item_disabled 	;
		$item_disabled	= (index("\U,$$d{config}{items}{$i}{flags},",",UI_READONLY,") ne -1) ? " read-only disabled " : $item_disabled;
		#
		# prepare to draw object in html
		if (index("\U,$$d{config}{items}{$i}{flags},",",UI_HIDDEN,") ne -1) {
			#
			# hide this guy
			#$html .= "<tr><td colspan=2>hidden $$d{config}{items}{$i}{title}: ";
			$html .= "<input type=hidden name='data$i' value='$item_value'>";
			#$html .= "</td></tr> ";
		} else {
			# 
			# we need html to draw this guy
			if ($$d{config}{items}{$i}{type} eq "NUMBER") {
				if ($$d{data}{items}{$i}{form_error} eq 1) {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i style='border:1px solid red;' value='$item_value' ><br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font></td>
			    	</tr>
				    ];
				} else {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i value='$item_value' > </td>
			    	</tr>
				    ];
				}
			}
			if ($$d{config}{items}{$i}{type} eq "STRING") {	
				if ($$d{data}{items}{$i}{form_error} eq 1) {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i style='border:1px solid red;' value='$item_value' ><br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font></td>
			    	</tr>
				    ];
				} else {
				    $html .= qq[
			    	<tr>
			    	<td valign=top>$$d{config}{items}{$i}{title}</td>
			    	<td valign=top><input $item_disabled name=data$i value='$item_value' > </td>
			    	</tr>
				    ];
				}
			}
			if ($$d{config}{items}{$i}{type} eq "SELECT") {	
				$tmp4 = ($$d{data}{items}{$i}{form_error} eq 1) ? "border:1px solid red;" : "";
				$tmp5 = ($$d{data}{items}{$i}{form_error} eq 1) ? "<br><font color=red size=1>$$d{config}{items}{$i}{error_message}</font>" : "";
				$tmp6 = "";
				foreach $tmp (sort{$a <=> $b} keys %{$$d{config}{items}{$i}{options}}) {
					$tmp1 = $$d{config}{items}{$i}{options}{$tmp}{value};
					$tmp2 = $$d{config}{items}{$i}{options}{$tmp}{title};
					$tmp3 = ($item_value eq $tmp1) ? " selected " : "";
					$tmp6 .= "<option $tmp3 value='$tmp1'>$tmp2</option>";
				}
			    $html .= qq[
		    	<tr>
		    		<td valign=top>$$d{config}{items}{$i}{title}</td>
		    		<td valign=top>
		    			<select $item_disabled name=data$i style='$tmp4' >
		    			<option value=''>...select...</option>
		    			<option value=''>&nbsp;</option>
		    			$tmp6
		    			</select>
		    			$tmp5
					</td>
		    	</tr>
			    ];
			}
		}
	}
	$form_hidden_elements = "";
	foreach $i (sort{$a <=> $b} keys %{$$fs{hidden_elements}}) {
		$form_hidden_elements .= "<input type=hidden name='$$fs{hidden_elements}{$i}{name}' value='$$fs{hidden_elements}{$i}{value}'>";
	}
    $html	.= qq[
		</table>
    	<br>
    	$form_message 
    	<button class=cancel type=button onclick="window.location='$$fs{url_button_cancel}'">Cancel</button>
    	<button class=save type=submit>Save</button>
    	$form_hidden_elements
    	<input type=hidden name=saveid value='$save_id'>
    </form>
    ];
	return $html;
}
#
#------------------------
# CSV tools
#------------------------
sub csvtools_line_split_values(){
	local($line_raw) = @_; 
	local(@array,%hash,$tmp,,$tmp1,$tmp2,@1,@a2);
	local(@values);
    chomp($line_raw);
    chomp($line_raw);
    if (index($line_raw,",") eq -1) {$tmp1 = "\t"; $tmp2=","; $line_raw =~ s/$tmp1/$tmp2/eg;}
	@data = ();
	foreach $tmp (split(/\,/,$line_raw)) {
		$tmp1="\""; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp1="\'"; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp = trim($tmp);
		@data = (@data,$tmp);
	}
	return (@data);
}
sub csvtools_line_join_values(){
	local(@d) = @_;
	return join(",",@d);
}
#
#------------------------
# data table
#------------------------
sub datatable_query_data(){
	my $d = shift @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2,$sql,$sql1,$sql2,$sql_id);
	local(%search_points,$word);
	#
	#---------------------------------------------------- 
	# clean start some things
	#---------------------------------------------------- 
	$$d{search} = &trim(&clean_str(substr($$d{search},0,1024),"()-_+"));
	$$d{data}{order_by}		= "";
	$$d{data}{selected_ids} = "";
	$$d{status}{search_is_possible}	= ( exists($$d{sql}{filter_ids_by_search}{search_points}) ) ? 1 : 0;
	$$d{status}{search_is_asked} 	= ($$d{search} eq "") ? 0 : 1;
	$$d{status}{search_is_enabled} 	= 0;
	$$d{data}{page_now} 			= &clean_int($$d{page});
	#
	#---------------------------------------------------- 
	# auto load/save page/search/order
	#---------------------------------------------------- 
	#
	#---------------------------------------------------- 
	# select ids by page/search 
	#---------------------------------------------------- 
	if ( ($$d{status}{search_is_possible} eq 1) && ($$d{status}{search_is_asked} eq 1)  ) {
		$$d{status}{search_is_enabled} = 1;
		$$d{data}{order_by}	= "SEARCH";
		#
		# search each word with all search_points sql and sum search points
		%{$$d{data}{search_points}} = ();
		foreach $word ( split(/ +/,$$d{search}) ) {
			foreach $sql_id (keys %{$$d{sql}{filter_ids_by_search}{search_points}}) {
				$sql = $$d{sql}{filter_ids_by_search}{search_points}{$sql_id};
				$tmp1="#WORD#"; $tmp2=$word; $sql =~ s/$tmp1/$tmp2/eg;
				%hash = database_select_as_hash($sql);
				foreach $tmp (keys %hash) { 
					$$d{data}{search_points}{$tmp} += $hash{$tmp}; 
				}
			}
		}
		#
		# get top 1000 ids
		@array = ();
		$tmp2 = 0;
		foreach $tmp1 (sort{$$d{data}{search_points}{$b} <=> $$d{data}{search_points}{$a}} keys %{$$d{data}{search_points}}) {
			@array = (@array,$tmp1);		
			$tmp2++;
			if ($tmp2>1000){last}
		}
		#
		# get ids by page
		$$d{data}{count} 		= @array;
		$$d{data}{count}		= ($$d{data}{count} eq "") ? 0 : $$d{data}{count};
		$$d{data}{page_size}	= &clean_int($$d{page_size});
		$$d{data}{page_size}	= ($$d{data}{page_size} eq "") ? 20 : $$d{data}{page_size};
		$$d{data}{page_size}	= ($$d{data}{page_size} > 1024) ? 1024 : $$d{data}{page_size};
		$$d{data}{page_size}	= ($$d{data}{page_size} < 1 ) ? 1 : $$d{data}{page_size};
		$$d{data}{page_min}		= 1;
		$$d{data}{page_max}		= int(($$d{data}{count}-1)/$$d{data}{page_size})+1;
		$$d{data}{page_max}		= ($$d{data}{page_max}<$$d{data}{page_min}) ? $$d{data}{page_min} : $$d{data}{page_max};
		$$d{data}{page_now} 	= ($$d{data}{page_now}<$$d{data}{page_min}) ? $$d{data}{page_min} : $$d{data}{page_now};
		$$d{data}{page_now} 	= ($$d{data}{page_now}>$$d{data}{page_max}) ? $$d{data}{page_max} : $$d{data}{page_now};
		$$d{data}{array_limit_1}	= ($$d{data}{page_now}-1)*$$d{data}{page_size};
		$$d{data}{array_limit_2}	= $$d{data}{array_limit_1}+$$d{data}{page_size}-1;
		$$d{data}{selected_ids} = "";
		foreach $tmp ($$d{data}{array_limit_1}..$$d{data}{array_limit_2}) {
			$tmp1 = (@array)[$tmp];
			if ($tmp1 eq "") {next}
			$$d{data}{selected_ids} .= $tmp1.",";
		}
		$$d{data}{selected_ids} = (substr($$d{data}{selected_ids},-1,1) eq ",") ? substr($$d{data}{selected_ids},0,-1) : $$d{data}{selected_ids};
	}
	#
	#---------------------------------------------------- 
	# select ids by page/order
	#---------------------------------------------------- 
	if ($$d{status}{search_is_enabled} eq 0) {
		# Get by page
		%hash = &database_select($$d{sql}{filter_ids_with_no_search}{get_total});
		$$d{data}{count} 		= ($hash{OK} eq 1) ? &clean_int($hash{DATA}{0}{0}) : 0;
		$$d{data}{count}		= ($$d{data}{count} eq "") ? 0 : $$d{data}{count};
		$$d{data}{page_size}	= &clean_int($$d{page_size});
		$$d{data}{page_size}	= ($$d{data}{page_size} eq "") ? 20 : $$d{data}{page_size};
		$$d{data}{page_size}	= ($$d{data}{page_size} > 1024) ? 1024 : $$d{data}{page_size};
		$$d{data}{page_size}	= ($$d{data}{page_size} < 1 ) ? 1 : $$d{data}{page_size};
		$$d{data}{page_min}		= 1;
		$$d{data}{page_max}		= int(($$d{data}{count}-1)/$$d{data}{page_size})+1;
		$$d{data}{page_max}		= ($$d{data}{page_max}<$$d{data}{page_min}) ? $$d{data}{page_min} : $$d{data}{page_max};
		$$d{data}{page_now} 	= ($$d{data}{page_now}<$$d{data}{page_min}) ? $$d{data}{page_min} : $$d{data}{page_now};
		$$d{data}{page_now} 	= ($$d{data}{page_now}>$$d{data}{page_max}) ? $$d{data}{page_max} : $$d{data}{page_now};
		$$d{data}{sql_limit_1}	= ($$d{data}{page_now}-1)*$$d{data}{page_size};
		$$d{data}{sql_limit_2}	= $$d{data}{page_size};
		if ($$d{data}{count} > 0){
			$$d{data}{order_by} = (exists($$d{sql}{filter_ids_with_no_search}{order_by}{$$d{order}})) ? $$d{order} : 0;
			$$d{data}{sql_order_by} = $$d{sql}{filter_ids_with_no_search}{order_by}{$$d{data}{order_by}}{sql}; 
			$tmp2=$$d{data}{sql_limit_1}; $tmp1="#LIMIT_1#"; $$d{data}{sql_order_by} =~ s/$tmp1/$tmp2/eg;
			$tmp2=$$d{data}{sql_limit_2}; $tmp1="#LIMIT_2#"; $$d{data}{sql_order_by} =~ s/$tmp1/$tmp2/eg;
			%hash = database_select_as_hash_with_auto_key($$d{data}{sql_order_by},"ID");
			$$d{data}{selected_ids} = "";
			foreach $tmp (sort{$a <=> $b} keys %hash){
				if ($hash{$tmp}{ID} eq "") {next}
				$$d{data}{selected_ids} .= $hash{$tmp}{ID}.",";
			}
			$$d{data}{selected_ids} = (substr($$d{data}{selected_ids},-1,1) eq ",") ? substr($$d{data}{selected_ids},0,-1) : $$d{data}{selected_ids};
		}
	}
	#
	#---------------------------------------------------- 
	# query data for selected ids
	#---------------------------------------------------- 
	if ($$d{data}{selected_ids} ne "") {
		$$d{data}{sql_get_data} = $$d{sql}{get_data};
		$tmp2=$$d{data}{selected_ids}; $tmp1="#SELECTED_IDS#"; $$d{data}{sql_get_data} =~ s/$tmp1/$tmp2/eg;
open(LLL,">>/tmp/111");
print LLL "$$d{data}{selected_ids} \n";
print LLL "$$d{data}{sql_get_data} \n\n\n";
close(LLL);
		%{$$d{data}{values}} = database_select_as_hash($$d{data}{sql_get_data},$$d{sql}{col_names});
	}
	#
	#---------------------------------------------------- 
	# return
	#---------------------------------------------------- 
	return 1;
}
sub datatable_get_html(){
	my $d = shift @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2);
	local($html,$line_id,$value,$col_id,$col_url,$col_sql_name,$col_flags,$col_value,$col_link_before,$col_link_after);
	#
	# make API changes compatible with old format
	unless (exists($$d{html}{cols})){
		$tmp = 0;
		@array1 = split(/\,/,$$d{html}{col_names});
		@array2 = split(/\,/,$$d{html}{col_titles});
		foreach $tmp1 (@array1){
			$$d{html}{cols}{$tmp}{data_col_name} = $tmp1;
			$$d{html}{cols}{$tmp}{title} 		= (@array2)[$tmp];
			$tmp++;
		}
	}
	$$d{html}{line_url} = ($$d{html}{line_url} eq "") ? $$d{html}{line_click_link} : $$d{html}{line_url};	
	#
	# prepare basic things
	$html = "";
	#
	# start table and form
	$html .= "<form action='$$d{html}{form}{action}' class=clear >";
	$html .= "<table width=100% border=0 colspan=0 cellpadding=0 cellspacing=0 class=WindowsTable>";
	#
	# start head
	$html .= "<thead>";
	#
	# add order by select / search and title
	if ( ($$d{html}{title} ne "") || ($$d{status}{search_is_possible} eq 1)  )  {
		$html .= "<tr><td colspan=100>";
		if ($$d{status}{search_is_possible}	eq 1) {
			$html .= "<button type=submit style='float:right;'>Search</button>";
			$html .= "<input type=text name='search' value='$$d{search}' style='height:27px;width:150px;float:right;'>";
		}
		if ($$d{html}{title} ne "") {
			$html .= "<h2>$$d{html}{title}</h2>";	
		}
		$html .= "</td></tr>";
	}
	#
	# add cols titles
	$html .= "<tr>";
	foreach $tmp1 (sort{$a <=> $b} keys %{$$d{html}{cols}}) {
		$tmp2 = $$d{html}{cols}{$tmp1}{width};
		$tmp2 = ($tmp2 ne "") ? " width=$tmp2 " : $tmp2;
		$html .= "<td $tmp2 >$$d{html}{cols}{$tmp1}{title}</td>";
	}
	$html .= "</tr>";
	#
	# stop head
	$html .= "</thead>";
	#
	# print data
	$html .= "<tbody  >";
	# rum lines
	foreach $line_id (split(/\,/,$$d{data}{selected_ids})) {
		$html .= "<tr>";
		# rum cols
		foreach $col_id (sort{$a <=> $b} keys %{$$d{html}{cols}}) {
			# get col
			$col_url		= $$d{html}{cols}{$col_id}{url};
			$col_url		= ($col_url eq "") ? $$d{html}{line_url} : $col_url;
			$col_sql_name	= $$d{html}{cols}{$col_id}{data_col_name};
			$col_flags		= "\U$$d{html}{cols}{$col_id}{flags}";
			$col_value		= $$d{data}{values}{$line_id}{$col_sql_name};
			# prepare col_url
			$col_link_after		= "";
			$col_link_before	= "";
			if ($col_url ne "") {
				foreach (split(/\,/,$$d{sql}{col_names})){
					$tmp1 = "\U#$_#";
					$tmp2 = $$d{data}{values}{$line_id}{$_};
					$col_url =~ s/$tmp1/$tmp2/eg;
				}
				$tmp1 = "#PAGE#";
				$tmp2 = $data{data}{page_now};
				$col_url =~ s/$tmp1/$tmp2/eg;
				$col_link_before	= "<a href=\"$col_url\">";
				$col_link_after		= "</a>";
			}
			# print
			$tmp = "<td>";
			$tmp = (index(",$col_flags,",",ALIGN_RIGHT,")  ne -1) ? "<td class=ar>" : $tmp;
			$tmp = (index(",$col_flags,",",ALIGN_LEFT,")   ne -1) ? "<td class=al>" : $tmp;
			$tmp = (index(",$col_flags,",",ALIGN_CENTER,") ne -1) ? "<td class=ac>" : $tmp;
			$html .= $tmp;
			$html .= $col_link_before;
			$tmp = $col_value;
			$tmp = (index(",$col_flags,",",FORMAT_DECIMAL,") ne -1) ? &format_number($col_value,0) : $tmp;
			$tmp = (index(",$col_flags,",",FORMAT_FLOAT_2_DIGITS,") ne -1) ? &format_number($col_value,2) : $tmp;
			$html .= $tmp;
			$html .= $col_link_after;
			$html .= "</td>";
		}
		$html .= "</tr>";
	}
	$html .= "</tbody>";
	#
	# print foot
	$html .= "<tfoot>";
	$html .= "<tr>";
	$html .= "<td colspan=100>";
		# button previous 
		$html .= "<button type=submit name=previous value=1>&#171;</button>";
		# select page
		$tmp1 = &format_number($$d{data}{page_max},0);
		$html .= "<select name=page onchange='this.form.submit()'>";
		foreach $tmp ($$d{data}{page_min}..$$d{data}{page_max}) {
			$tmp2 = ($tmp eq $$d{data}{page_now}) ? "selected" : "";
			$html .= "<option $tmp2 value='$tmp'>Page ". &format_number($tmp,0) ." of $tmp1</option>";
		}		
		$html .= "</select>";
		# page size select 
		$html .= "<select name=page_size onchange='this.form.submit()'>";
		$tmp1=20; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$tmp1=50; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$tmp1=300; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$html .= "</select>";
		# order select
		$html .= "<select name=order onchange='this.form.submit()'>";
		$html .= "<option>Automatic order</option>";
		foreach $tmp (sort{$a <=> $b} keys %{$$d{sql}{filter_ids_with_no_search}{order_by}}){
			$tmp1 = ($$d{data}{order_by} eq $tmp) ? "selected" : "";
			$html .= "<option $tmp1 value='$tmp'>$$d{sql}{filter_ids_with_no_search}{order_by}{$tmp}{title}</option>";
		}
		$html .= "</select>";
		# button next
		$html .= "<button type=submit name=next value=1>&#187;</button>";
	$html .= "</td>";
	$html .= "</tr>";
	$html .= "</tfoot>";
	#
	# print hidden data values
	foreach $tmp (keys %{$$d{html}{form}{data}}) {
		$html .= "<input type=hidden name='".$$d{html}{form}{data}{$tmp}{name}."' value='".$$d{html}{form}{data}{$tmp}{value}."'>";
	}
	#
	# end table and form
	$html .= "</table>";
	$html .= "</form>";
	#
	# return
	return $html;
}
sub DELETE_datatable_get_html(){
	my $d = shift @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2);
	local($html,$line_id);
	#
	# prepare basic things
	$$d{html}{col_names}	= ($$d{html}{col_names} 	eq "") ? $$d{sql}{col_names}	: $$d{html}{col_names};
	$$d{html}{col_titles}	= ($$d{html}{col_titles}	eq "") ? $$d{html}{col_names}	: $$d{html}{col_titles};
	$html = "";
	#
	# start table and form
	$html .= "<form action='$$d{html}{form}{action}' class=clear >";
	$html .= "<table width=100% border=0 colspan=0 cellpadding=0 cellspacing=0 class=WindowsTable>";
	#
	# start head
	$html .= "<thead>";
	#
	# add order by select / search and title
	if ( ($$d{html}{title} ne "") || ($$d{status}{search_is_possible} eq 1)  )  {
		$html .= "<tr><td colspan=100>";
		if ($$d{status}{search_is_possible}	eq 1) {
			$html .= "<button type=submit style='float:right;'>Search</button>";
			$html .= "<input type=text name='search' value='$$d{search}' style='height:27px;width:150px;float:right;'>";
		}
		if ($$d{html}{title} ne "") {
			$html .= "<h2>$$d{html}{title}</h2>";	
		}
		$html .= "</td></tr>";
	}
	#
	# add cols titles
	$html .= "<tr>";
	foreach $tmp2 (split(/\,/,$$d{html}{col_titles})){
		$html .= "<td>$tmp2</td>";
	}
	$html .= "</tr>";
	#
	# stop head
	$html .= "</thead>";
	#
	# print data
	$html .= "<tbody  >";
	@array1 = split(/\,/,$$d{data}{selected_ids});
	@array2 = split(/\,/,$$d{html}{col_names});
	@array3 = split(/\,/,$$d{sql}{col_names});
	foreach $line_id (@array1) {
		$tmp3 = $$d{html}{line_click_link};
		foreach $col_id (@array3){
			$tmp2 = $$d{data}{values}{$line_id}{$col_id};
			$tmp1 = "\U#$col_id#";
			$tmp3 =~ s/$tmp1/$tmp2/eg;
		}
		$tmp2 = $data{data}{page_now};
		$tmp1 = "#PAGE#";
		$tmp3 =~ s/$tmp1/$tmp2/eg;
		$html .= "<tr>";
		foreach $col_id (@array2){
			$html .= "<td>";
			$html .= "<a href=\"$tmp3\">$$d{data}{values}{$line_id}{$col_id}</a>";
			$html .= "</td>";
		}
		$html .= "</tr>";
	}
	$html .= "</tbody>";
	#
	# print foot
	$html .= "<tfoot>";
	$html .= "<tr>";
	$html .= "<td colspan=100>";
		# button previous 
		$html .= "<button type=submit name=previous value=1>&#171;</button>";
		# select page
		$tmp1 = &format_number($$d{data}{page_max},0);
		$html .= "<select name=page onchange='this.form.submit()'>";
		foreach $tmp ($$d{data}{page_min}..$$d{data}{page_max}) {
			$tmp2 = ($tmp eq $$d{data}{page_now}) ? "selected" : "";
			$html .= "<option $tmp2 value='$tmp'>Page ". &format_number($tmp,0) ." of $tmp1</option>";
		}		
		$html .= "</select>";
		# page size select 
		$html .= "<select name=page_size onchange='this.form.submit()'>";
		$tmp1=20; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$tmp1=50; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$tmp1=300; $tmp2 = ($tmp1 eq $$d{data}{page_size}) ? "selected" : ""; $html .= "<option $tmp2 value='$tmp1'>". &format_number($tmp1,0) ." itens per page</option>";
		$html .= "</select>";
		# order select
		$html .= "<select name=order onchange='this.form.submit()'>";
		$html .= "<option>Automatic order</option>";
		foreach $tmp (sort{$a <=> $b} keys %{$$d{sql}{filter_ids_with_no_search}{order_by}}){
			$tmp1 = ($$d{data}{order_by} eq $tmp) ? "selected" : "";
			$html .= "<option $tmp1 value='$tmp'>$$d{sql}{filter_ids_with_no_search}{order_by}{$tmp}{title}</option>";
		}
		$html .= "</select>";
		# button next
		$html .= "<button type=submit name=next value=1>&#187;</button>";
	$html .= "</td>";
	$html .= "</tr>";
	$html .= "</tfoot>";
	#
	# print hidden data values
	foreach $tmp (keys %{$$d{html}{form}{data}}) {
		$html .= "<input type=hidden name='".$$d{html}{form}{data}{$tmp}{name}."' value='".$$d{html}{form}{data}{$tmp}{value}."'>";
	}
	#
	# end table and form
	$html .= "</table>";
	$html .= "</form>";
	#
	# return
	return $html;
}
#
#------------------------
# form check libs
#------------------------
# i just prototype this things..
# not working as the way i want
# later need comeback and fix the magic
#------------------------
sub form_check_float(){
	my ($v,$f) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	$v++;
	$v--;
	if ($v eq "0") {return 1}
	if ($v>0) {return 1}
	if ($v<0) {return 1}
	return 0;
}
sub form_check_integer(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_number(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_string(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_url(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /&?-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_textarea(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," -_–(\@)-,=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_sql(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," *-_–(\@)-,<>=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_email(){
	my ($v) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	if ($v ne &clean_str($v,"–()_-=+;.?<>@","MINIMAL")) {return 0}
	if (index($v,"@") eq -1) {return 0}
	return 1;
}
#------------------------
#
#------------------------
# image check
#------------------------
sub imagecheck_new(){
	local($uid,$key,$folder);
	$folder = "$app_root/tmp/imagecheck";
	#
	# crate a uid
	$tmp = $ENV{REMOTE_ADDR}.$ENV{REMOTE_PORT}.$ENV{HTTP_USER_AGENT}.time;
	$uid = key_md5($tmp);
	#
	# create a key
	#$tmp = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	#$tmp = "0123456789";
	$tmp = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	$tmp = $tmp.$tmp.$tmp.$tmp.$tmp.$tmp;
	$key = "";
	$key .= substr($tmp,int(rand(40)),1);
	$key .= substr($tmp,int(rand(40)),1);
	$key .= substr($tmp,int(rand(40)),1);
	$key .= substr($tmp,int(rand(40)),1);
	#
	# create text uid e guarda key nela
	&database_do("replace into system_captcha (uid,value) values ('$uid','$key') ");
	#
	# retorna uid
	return $uid;
}
sub imagecheck_get_image(){
	local($uid) = @_;
	local($tmp,$key,$folder);
	$folder = "/tmp/";
	#
	# verifica uid existe
	$uid = trim(clean_str(substr($uid,0,100)));
	if ($uid eq "") {return}	
	%hash = database_select_as_hash("SELECT 1,1,value FROM system_captcha where uid='$uid' ","flag,value");
	if ($hash{1}{flag} ne 1) {return}	
	if ($hash{1}{value} eq "") {return}	
	$key = $hash{1}{value};
	#
	# gera image file
	$tmp = "/usr/bin/convert -fill blue -pointsize 20 -gravity center -size 50x30 xc:white -annotate 20x10+0+0 '$key' -wave 1x3 $folder/$uid.gif ";
	$tmp = "/usr/bin/convert -font Liberation-Serif-Italic -fill blue -pointsize 20 -gravity center -size 50x30 xc:white -annotate 20x10+0+0 '$key' -wave 1x3 $folder/$uid.gif ";
	$tmp = `$tmp`;
	open (IMAGECHECK,"$folder/$uid.gif");
	print "Content-type: image/png\n\n";
	binmode STDOUT;
	while ( read( IMAGECHECK, $buffer, 16_384 ) ) {print $buffer;}
	close(IMAGECHECK);
	unlink("$folder/$uid.gif");
}
sub imagecheck_check(){
	local($uid,$key) = @_;
	local($tmp,$folder,$dbkey);
	local ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	#
	# confere se uid existe
	$uid = trim(clean_str(substr($uid,0,100)));
	$key = trim(clean_str(substr($key,0,100)));
	if ($uid eq "") {return 0}
	if ($key eq "") {return 0}
	%hash = database_select_as_hash("SELECT 1,1,value FROM system_captcha where uid='$uid' ","flag,value");
	if ($hash{1}{flag} ne 1) {return 0}	
	if ($hash{1}{value} eq "") {return 0}	
	$dbkey = $hash{1}{value};
	#
	# captcha garbage collector (run once per hour only)
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime(time);
	if (&system_config_get("captcha","last_clean") ne $hour) {
		&system_config_set("captcha","last_clean",$hour);
		&database_do("delete FROM system_captcha  where timestamp < date_sub(now(),interval 30 minute)");
	}
	&database_do("delete FROM system_captcha where uid='$uid' ");
	#
	# confere se key esta correta
	if ("\U$key" eq "\U$dbkey") {return 1;} else {return 0;}
}
#------------------------
#
#------------------------
# www session/user persistence 
#------------------------
sub session_init()	{
	local(%cookie,$cookie_u,$cookie_k,$tmp_gap);
	#
	# check if this web session is ok.
	#
	# read cookies (k is uid session, u is login_id just to make things easy for api)
	%cookie	= &cookie_read();
	$cookie_k = &clean_int(substr($cookie{$app{session_cookie_k_name}},0,100));
	$cookie_u = &clean_int(substr($cookie{$app{session_cookie_u_name}},0,100));
	$app{session_cookie_u}	= "";
	$app{session_cookie_k}	= "";
	#
	# no cookie, return  0
	if ($cookie_k eq "") {return 0}
	if ($cookie_u eq "") {return 0}
	#
	# if no session, return -31 (some one try to create arbritary session cookie or old old session cookie)
	if (&session_get($cookie_k,"active") ne 1) {return -31}
	#
	# if active ip and session ip mismatch, return -32 (maybe user move to new ip or some one try to spoof session cookie)
	if (&session_get($cookie_k,"ip") ne $ENV{REMOTE_ADDR}) {return -32}
	#
	# if cookie_u mismatch from session, return -33 (a bad spoofed cookie set)
	if (&session_get($cookie_k,"login_id") ne $cookie_u) {return -32}
	#
	# if user dows not exists, logout and return -2
	if (&user_exists($cookie_u) ne 1) { &session_detach($key); return -2 }
	#
	# if timeout, return -1
	if ($app{session_logout_on_timeout} eq 1) {
		$tmp_sec = &session_get($cookie_k,"time_last_access");
		$tmp_sec = ($tmp_sec > 100) ? $tmp_sec : time ;
		$tmp_gap = time - $tmp_sec;
		if ($tmp_gap > $app{session_timeout_seconds}) {
			&session_detach($cookie_k);
			return -1
		}
	}
	#
	# all ok, just touch session:time_last_access
	&session_set($cookie_k,"time_last_access",time);
	$app{session_cookie_u}		= $cookie_u;
	$app{session_cookie_k}		= $cookie_k;
	return 1;
}
sub session_attach()	{
	local($login_id) = @_;
	local($key,%acc,$sql);
	#
	# check if user_id exists
	$sql = "select 1,1,$app{users_col_id} from $app{users_table} where $app{users_col_id} = '$login_id' ";
	%acc = database_select_as_hash($sql,"flag,id");
	unless ($acc{1}{flag} eq 1) {return 0}
	unless ($acc{1}{id} eq $login_id) {return 0}
	#
	# create uid, create session with uid, add uid at cookie
	if ($cookie{$app{session_cookie_k_name}} ne "") {&session_delete($cookie{$app{session_cookie_k_name}})}
	$key = substr("0000".int(1000*rand()),-4,4) . time . substr("0000".int(1000*rand()),-4,4);
	&session_set($key,"active"			,"1");
	&session_set($key,"login_id"		,$acc{1}{id});
	&session_set($key,"ip"				,$ENV{REMOTE_ADDR});
	&session_set($key,"time_login"		,time);
	&session_set($key,"time_last_access",time);
	#
	# rotate login and last login date
	&user_set($login_id,"time_login_last",&user_get($login_id,"time_login") );
	&user_set($login_id,"time_login",time);
	#
	# set cookie (k is uid session, u is login_id just to make things easy for api)
	&cookie_save($app{session_cookie_k_name},$key);
	&cookie_save($app{session_cookie_u_name},$acc{1}{id});
	#
	# save things and return
	$app{session_cookie_u}	= $acc{1}{id};
	$app{session_cookie_k}	= $key;
	return 1;
}
sub session_detach()	{
	local($key);
	local(%cookie,$key);
	if ($key eq "") {
		%cookie	= &cookie_read();
		$key = $cookie{$app{session_cookie_k_name}};
	}
	$key = &clean_int(substr($key,0,100));
	if ($key eq "") {return}
	$app{session_status} = 0;
	&cookie_save($app{session_cookie_k_name},"");
	&cookie_save($app{session_cookie_u_name},"");
	&session_delete($key);
}
sub session_get()	{
	local($key,$name) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return data_get($app{session_table},$key,$name);
}
sub session_set()	{
	local($key,$name,$value) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return data_set($app{session_table},$key,$name,$value);
}
sub session_delete()	{
	local($key) = @_;
	if ($key  eq "") {return ""}
	foreach (&data_get_names($app{session_table},$key)) {
		##$dbg .= "SESSION_DELETE : delete name ($_) <br>";
		&data_delete($app{session_table},$key,$_);
	}
}
sub active_session_set()	{
	local($name,$value) = @_;
	if ($app{session_status} ne 1)	{return ""}
	if ($app{session_cookie_k} eq "")	{return ""}
	return  &session_set($app{session_cookie_k},$name,$value);
}
sub active_session_get()	{
	local($name) = @_;
	if ($app{session_status} ne 1)		{return ""}
	if ($app{session_cookie_k} eq "")	{return ""}
	return  &session_get($app{session_cookie_k},$name);
}
sub active_session_delete()	{
	local($name) = @_;
	if ($app{session_status} ne 1)		{return ""}
	if ($app{session_cookie_k} eq "")	{return ""}
	return &data_delete($app{session_table},$app{session_cookie_k},$name);
}
sub active_user_get()	{
	local($name) = @_;
	if ($app{session_status} ne 1)	{return ""}
	if ($app{session_cookie_u} eq "")	{return ""}
	return  &user_get($app{session_cookie_u},$name);
}
sub active_user_set()	{
	local($name,$value) = @_;
	if ($app{session_status} ne 1)		{return ""}
	if ($app{session_cookie_u} eq "")	{return ""}
	return  &user_set($app{session_cookie_u},$name,$value);
}
sub user_exists()	{
	local($old_acc) = @_;
	local($acc);
	$acc = &clean_int(substr($old_acc,0,250));
	if ($acc eq "") {return 0};
	if ($acc ne $old_acc) {return 0};
	if ( database_do("select 1 from $app{users_table} where $app{users_col_id} = '$acc'") eq 1) {
		return 1;
	} else {
		return 0;
	}
}
sub user_get()	{
	local($acc,$name) = @_;
	local(%tmp,$acc_id);
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($name eq "") {return ""}
	if (&user_exists($acc) ne 1) {return 0}
	return data_get($app{users_options_table},$acc,$name);
}
sub user_set()	{
	local($acc,$name,$value) = @_;
	local(%tmp,$acc_id);
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($name eq "") {return ""}
	if (&user_exists($acc) ne 1) {return 0}
	$value	= substr($value,0,250);
	return data_set($app{users_options_table},$acc,$name,$value);
}
sub system_config_get(){
	local($key,$name) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return data_get("system_config",$key,$name);
}
sub system_config_set(){
	local($key,$name,$value) = @_;
	if ($key  eq "") {return ""}
	if ($name eq "") {return ""}
	return data_set("system_config",$key,$name,$value);
	
}
#
#------------------------
# read user permission 
# TODO: i think this is not in use anymore. need check
#------------------------
sub user_permission_cache_load(){
	local($acc_id) = @_;
	local($id,$tmp,$tmp1,$tmp2,%out,%hash,$sql);
	$acc_id = &clean_int(substr($acc_id,0,250));
	#
	# check if cache is already loaded
	if ($app_session{user_permission}{ok} eq 1) {return}
	#
	# clean
	%{$app_session{user_permission}}		= ();
	$app_session{user_permission}{ok} 		= 0;
	$app_session{user_permission}{user_ok}	= 0;
	#
	# load default data
	#$sql = "SELECT id,default_value FROM system_user_group_permission_dictionary";
	#%hash = database_select_as_hash($sql,"value");
	#foreach $id (keys %hash) {
	#	$app_session{user_permission}{$id} = $hash{$id}{value};
	#}
	#
	# find group_id for this user
	$sql = "SELECT 1,1,group_id FROM system_user where id='$acc_id' ";
	%hash = database_select_as_hash($sql,"flag,value");
	$app_session{user_permission}{user_group_id} = ( ($hash{1}{flag} eq 1) && ($hash{1}{value}>=0)) ? $hash{1}{value} : "";
	#
	# load group specific values
	if ($app_session{user_permission}{user_group_id} ne "") {
	$sql = "SELECT dictionary_id,value FROM system_user_group_permission_value where group_id='$app_session{user_permission}{user_group_id}' ";
		$app_session{user_permission}{user_ok}	= 1;
		%hash = database_select_as_hash($sql,"value");
		foreach $id (keys %hash) {
			$app_session{user_permission}{$id} = $hash{$id}{value};
		}
	}
	#
	# return
	$app_session{user_permission}{ok} 		= 1;
	return
}
sub user_permission_check(){
	local($acc_id,$name) = @_;
	local($tmp);
	return (&user_permission_get($acc_id,$name) > 0) ? 1 : 0;
}
sub user_permission_get(){
	local($acc_id,$name) = @_;
	local(%hash,$sql);
	$acc_id	= &clean_int(substr($acc_id,0,250));
	$name	= &clean_str(substr($name,0,250),	"._-:","MINIMAL");
	if ($name eq "") {return ""}
	if ($acc_id eq "") {return ""}
	&user_permission_cache_load($acc_id);
	if (exists($app_session{user_permission}{$name})) {return $app_session{user_permission}{$name}}
	return "";
}
sub active_user_permission_get(){
	local($name) = @_;
	if ($app{session_status} ne 1)	{return 0}
	if ($app{session_cookie_u} eq "")	{return 0}
	return  &user_permission_get($app{session_cookie_u},$name);	
}
sub active_user_permission_check(){
	local($name) = @_;
	if ($app{session_status} ne 1)	{return 0}
	if ($app{session_cookie_u} eq "")	{return 0}
	return  &user_permission_check($app{session_cookie_u},$name);	
}
#------------------------
#
#------------------------
# generic data persistence (get/set values in data table)
#------------------------
sub data_get(){
	#
	# get clean and reject 
	local($table,$target,$name) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	#
	# lets translate some things
	#$table = ($table eq "system_config") ? "app_data" : $table; 
	#
	# start work
	local ($value,$tmp1,$tmp2);
	$value = "";
	foreach ( &database_select_as_array("select value from $table where target='$target' and name='$name'") ) {$value .= $_;}
	#
	# todo: wtf is this?
	$tmp1="<>"; $tmp2="\n"; $value =~ s/$tmp1/$tmp2/eg;
	#
	# return
	return $value;
}
sub data_get_names(){
	local($table,$target) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	return &database_select_as_array("select name from $table where target='$target' ");
}
sub data_set(){
	local($table,$target,$name,$value) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-,","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-,","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-,","MINIMAL");
	#
	# TODO HACK CHECK
	# check if enable % into value its a open gate to crackers
	#
	$value	= &database_escape(&clean_str(substr($value,0,250),	" ._,-&@()*[]=%<>\$/?","MINIMAL"));
	##$dd .= "DATA_SET : START ($table,$target,$name,$value) <br>";
	if ($table eq "") {return ""}
	##$dd .= "DATA_SET : SQL 1 (delete from $table where target='$target' and name='$name') <br>";
	##$dd .= "DATA_SET : SQL 2 (insert into $table (target,name,value) values ('$target','$name','$value')) <br>";
	database_do("delete from $table where target='$target' and name='$name'");
	database_do("insert into $table (target,name,value) values ('$target','$name','$value') ");
}
sub data_delete(){
	local($table,$target,$name) = @_;
	$table	= &clean_str(substr($table,0,250),	"._-","MINIMAL");
	$target	= &clean_str(substr($target,0,250),	"._-","MINIMAL");
	$name	= &clean_str(substr($name,0,250),	"._-","MINIMAL");
	if ($table eq "") {return ""}
	database_do("delete from $table where target='$target' and name='$name'");
}
#------------------------
#
#------------------------
# md5 
# TODO: who is using that? i think only CC_fingerprint 
#------------------------
sub key_generate(){
	local($seed) = @_;
	local($cmd,$buf,$out,$tmp,$tmp1,$tmp2,$t);
	$t = time;
	$seed = "$seed|$t|";
	$out = key_md5($seed);
	#$out = `$app_folder_bin/echo "$seed" | $app_folder_bin/md5sum 2>/dev/null`;
	$out = substr($out,0,32).$t;
	return $out;
}
sub key_get_seconds(){
	# -1 for bad key
	local($test_key) = @_;
	return (time - int(substr($test_key,32,1000)) );
}
sub key_check(){
	local($test_key,$seed) = @_;
	local($ok_key,$cmd,$buf,$out,$tmp,$tmp1,$tmp2,$t);
	$seed = "$seed|".substr($test_key,32,1000)."|";
	$ok_key = key_md5($seed);
	#$ok_key = `$app_folder_bin/echo "$seed" | $app_folder_bin/md5sum 2>/dev/null`;
	$ok_key = substr($ok_key,0,32).substr($test_key,32,1000);
	if ($ok_key eq $test_key){
		return 1;
	} else {
		return 0;
	}
}
sub key_md5(){
	local($in) =@_;
	return md5_hex($in);
}
#------------------------
#
#------------------------
# generic cgi library
#------------------------
sub cookie_save($$) {
	local($name,$value,$flags)=@_;
	$flags = ($flags eq "") ? "" : "$flags;";
	print "Set-Cookie: ";
	print $name."=".$value."; path=/; $flags  \n";
	#print $name."=".$value."; path=/; $flags expires=Sun, 26-Jun-2011 00:00:00 GMT; \n";
	#print $name."=".$value."; path=/; $flags expires=Sun, 26-Jun-2011 00:00:00 GMT; domain=$ENV{SERVER_NAME};\n";
	#print ($name,"=",$value,"; path=/; \n");
}
sub cookie_read{
	local(@rawCookies) = split (/; /,$ENV{'HTTP_COOKIE'});
	local(%r);
	foreach(@rawCookies){
		($key, $val) = split (/=/,$_);
		$r{$key} = $val;
	}
	return %r;
}
sub cgi_hearder_html {
  print "Content-type: text/html\n";
  #print "Cache-Control: no-cache, must-revalidate\n";
  #print "Pragma: no-cache\n";
  print "\n";
}
sub cgi_redirect {
  local($url) = @_;
  print "Content-type: text/html\n";
  print "Cache-Control: no-cache, must-revalidate\n";
  print "Pragma: no-cache\n";
  print "status: 302\n";
  # we should use 303 http://en.wikipedia.org/wiki/List_of_HTTP_status_codes
  print "location: $url\n";
  print "\n";
  #print "<meta http-equiv='refresh' content='0;URL=$url'>";
  #print "<script>window.location='$url'</script>";
  print "\n";
}
sub cgi_url_encode {
    defined(local $_ = shift) or return "";
    s/([" %&+<=>"])/sprintf '%%%.2X' => ord $1/eg;
    $_
}
sub cgi_url_decode {
  local($trab)=@_;
  $trab=~ tr/+/ /;
  $trab=~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  return $trab;
}
sub cgi_mime_get_from_file(){
	#
	# get mime type. need mimetype, lame sox to find exactly
	#
	local($file) = @_;
	local($tmp,$tmp1,$tmp2);
	local($cmd,$ans);
	#
	# get first by mimetype
	$tmp= `/usr/bin/mimetype -b -M "$file" 2>/dev/null `;
	chomp($tmp);
	#
	# lest get deep check for application/octet-stream
	if ($tmp eq "application/octet-stream") {
		$tmp1="";
		#
		# check mp3
		if ($tmp1 eq "") {
			$tmp2 = `/usr/bin/mpg123 -t -n 10 "$file" 2>&1`;
			if (index($tmp2,"MPEG 1.0 layer III") ne -1) { $tmp1 = "audio/mpeg"} 
			if (index($tmp2,"MPEG 2.0 layer III") ne -1) { $tmp1 = "audio/mpeg"} 
		}
		#
		# check simple (trust extension)
		if ($tmp1 eq "") {
			$tmp1= `/usr/bin/mimetype -b "$file" 2>/dev/null `;
			chomp($tmp1);
		}
		#
		# return then 
		$tmp = ($tmp1 eq "") ? "application/octet-stream" : $tmp1;
	}
	#
	return $tmp;
}
sub cgi_check_ip_flood(){
	if ($ENV{REMOTE_ADDR} eq "127.0.0.1") {return}
	local ($section) = @_;
	local ($ip) = $ENV{REMOTE_ADDR};
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash,$counter_1,$counter_2,$timestamp);
	$counter_1	= 0;
	$counter_2	= 0;
    %hash = database_select_as_hash("SELECT 1,1,counter_1,counter_2,unix_timestamp(timestamp) FROM system_ip_flood where ip='$ip'","flag,counter_1,counter_2,timestamp");
	if ($hash{1}{flag} eq 1) {
		$counter_1	= ($hash{1}{counter_1}	ne "") ? $hash{1}{counter_1}: 0;
		$counter_2	= ($hash{1}{counter_2}	ne "") ? $hash{1}{counter_2}: 0;
		$timestamp	= ($hash{1}{timestamp}	ne "") ? $hash{1}{timestamp}: time;
		if ( (time-$timestamp)<(60) 	) {$counter_1++;} else {$counter_1 = 0;}
		if ( (time-$timestamp)<(60*10) 	) {$counter_2++;} else {$counter_2 = 0;}
		&database_do("
			update system_ip_flood set
			counter_1 = '$counter_1',
			counter_2 = '$counter_2',
			timestamp  = now()
			where ip='$ip'
		");
	} else {
		&database_do("
			insert into system_ip_flood
			(ip,     timestamp,  counter_1,   counter_2   ) values
			('$ip',  now(),      '1',         '1'         )
		");
		$counter_1	= 1;
		$counter_2	= 1;
	}
	if ( ($counter_1 > 10) || ($counter_2 > 60) ) {
		print "Content-type: text/html\n";
		print "Cache-Control: no-cache, must-revalidate\n";
  		print "status:503\n";
		print "\n";
		print qq[
		<body bgcolor=#ffffff color=#000000 >
		<font face=verdana,arial size=2>
		<div 						style="padding:50px;">
		<div class=alert_box 		style="width:600px;padding:0px;margin:0px;border:1px solid #f8d322;background-color:#fff18e;">
		<div class=alert_box_inside	style="padding:0px;border:0px;margin-top:4px;margin-left:7px;margin-right:5px;margin-bottom:7px;padding-left:22px;padding-top:0px;background-image:url(/design/icons/forbidden.png);background-repeat:no-repeat;background-position:0 3;">
		<font size=3><b>Warning</b>:</font><br>
		You triggered website surge protection by doing too many requests in a short time.<br>
		Please make a short break, slow down and try again.<br>
		</div>
		</div>
		</div>
		];
		exit;
	}
}

#------------------------
#
#------------------------
# database abstraction
#------------------------
sub database_connect(){
	if ($database_connected eq 0) {
		$database = DBI->connect($database_dsn, $database_user, $database_password);
		$database->{mysql_auto_reconnect} = 1;
		$database_connected = 1;
	}
}
sub database_select(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$cols_string)=@_;
	local (@rows,@cols_name,$connection,%output,$row,$col,$col_name);
	@cols_name = split(/\,/,$cols_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$row=0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$col=0;
			foreach (@rows){
				$col_name =  ((@cols_name)[$col] eq "")  ? $col : (@cols_name)[$col] ; 
				$output{DATA}{$row}{$col_name}= $_;
				#$output{DATA}{$row}{$col}= &database_scientific_to_decimal($_);
				$col++;
			}
			$row++;
		}
		$output{ROWS}=$row;
		$output{COLS}=$col;
		$output{OK}=1;
	} else {
		$output{ROWS}=0;
		$output{COLS}=0;
		$output{OK}=0;
	}
	return %output;
}
sub database_select_as_hash(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			if ($rows_string eq "") {
				$output{(@rows)[0]}=(@rows)[1];
			} else {
				$i=0;
				foreach (@rows_name) {
					##$output{(@rows)[0]}{$_} = &database_scientific_to_decimal((@rows)[$i+1]);
					$output{(@rows)[0]}{$_} = (@rows)[$i+1];
					$i++;
				}
			}
		}
	}
	return %output;
}
sub database_select_as_hash_with_auto_key(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output,$line_id);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$line_id = 0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$i=0;
			foreach (@rows_name) {
				$output{$line_id}{$_} = &database_scientific_to_decimal((@rows)[$i]);
				$i++;
			}
			$line_id++;
		}
	}
	return %output;
}
sub database_select_as_array(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,@output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			@output = ( @output , &database_scientific_to_decimal((@rows)[0]) );
		}
	}
	return @output;
}
sub database_do(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output);
	$output = "";
	if ($database_connected eq 1) {	$output = $database->do($sql) }
	if ($output eq "") {$output =-1;}
	return $output;
}
sub database_scientific_to_decimal(){
	local($out)=@_;
	local($tmp1,$tmp2);
	if ( index("\U$out","E-") ne -1) {
		($tmp1,$tmp2) = split("E-","\U$out");
 		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=sprintf("%f",$out);
		}
	}
	if ( index("\U$out","E+") ne -1) {
		($tmp1,$tmp2) = split("E","\U$out");
		$tmp2 = substr($tmp2,1,10);
		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=int(sprintf("%f",$out));
		}
	}
	return $out;
}
sub database_clean_string(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_clean_number(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_escape {
	my $string = @_[0];
	$string =~ s/\\/\\\\/g ; # first escape all backslashes or they disappear
	$string =~ s/\n/\\n/g ; # escape new line chars
	$string =~ s/\r//g ; # escape carriage returns
	$string =~ s/\'/\\\'/g; # escape single quotes
	$string =~ s/\"/\\\"/g; # escape double quotes
	return $string ;
}
sub database_do_insert(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output,%hash,$tmp);
	$output = "";
	#
	# new code (return last insert_id)
	if ($database_connected eq 1) {
		if ($database->do($sql)) {
			%hash = &database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
			return $hash{1};
		} else {
			return "";
		}
	} else {
		return "";
	}
}
sub database_escape_sql(){
	local($sql,@values) = @_;
	retutn &database_scape_sql($sql,@values);
}
sub database_scape_sql(){
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	$tmp--;
	if ($tmp>0) {
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	return  sprintf($sql,@values);
}
#------------------------
#
#------------------------
# html template 
# TODO: Delete old not used calls. I think we only use template_print and maybe template_print_error*
#------------------------
sub template_start(){
	local($flag) = @_;
	local($tmp,$file,$menu);
	if (index("\L$flag",".html") eq -1) {
		$menu = ( ($flag eq "") && ($my_menu ne "") ) ? $my_menu : $flag;
		$file = "template.html";
	} else {
		$menu = $my_menu;
		$file = $flag;
	}
	cgi_hearder_html();
	open (TEMPLATE,$file);
	while(<TEMPLATE>){
		if (index($_,"##CONTENT##") ne -1) {last;	}
		print $_;
	}
	if ($app{session_status} eq 1) {
		if (&security_check("clients_allow")) 	{print "<script>menu_enable('clients')</script>";}
		if (&security_check("products_allow"))	{print "<script>menu_enable('products')</script>";}
		if (&security_check("agents_allow"))	{print "<script>menu_enable('agents')</script>";}
		if (&security_check("reports_allow"))	{print "<script>menu_enable('reports')</script>";}
		print "<script>menu_enable('logout')</script>";
		print "<script>menu_select('$menu')</script>";
	}
	print "<script>MyHTML('page_title','$app{name}')</script>";
	close(TEMPLATE);
}
sub template_end(){
	local($flag) = @_;
	local($tmp,$file,$switch);
	$file = (index("\L$flag",".html") eq -1) ? "template.html" : $flag;
	$switch=0;
	open (TEMPLATE,$file);
	while(<TEMPLATE>){
		if ($switch eq 1) {print $_;}
		if (index($_,"##CONTENT##") ne -1) {$switch = 1}
	}
	close(TEMPLATE);
	#print "<br clear=both><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><div style='background:#ffffff; font-size:10px;'>";
	#foreach(sort keys %app) {print "APP - [$_] - [$app{$_}] <br>"}
	#foreach(sort keys %form) {print "FORM - [$_] - [$form{$_}] <br>"}
	#foreach(sort keys %ENV) {print "ENV - [$_] - [$ENV{$_}] <br>"}
	#print "</div>";
}
sub template_bar(){
        local($w,$h,$t,$v,$color1,$color2) = @_;
        local($html,$v1,$v2,$label);
        $w++;
	$h++;
	$t++;
	$v++;
        $w--;
	$h--;
	$t--;
	$v--;
        $html = "";
        if ($v > $t) {$t = $v}
        $v1 = ($t ne 0) ? int($w*($v/$t)) : 0;
        $v2 = $w - $v1;
        $label= ($t ne 0) ? int(100*($v/$t))."%" : "0%";
        #$html = "<table border=0 cellspacing=0 cellpadding=0 style='border:0px;marging:0px;padding:0px;' >";
        #if ($v1 >0) {$html .= "<td style='border:0px;marging:0px;padding:0px;' bgcolor=$color1><img alt='$label' title='$label' src=/spc.gif width=$v1 height=$h hspace=0 vspace=0></td>";}
        #if ($v2 >0) {$html .= "<td style='border:0px;marging:0px;padding:0px;' bgcolor=$color2><img alt='$label' title='$label' src=/spc.gif width=$v2 height=$h hspace=0 vspace=0></td>";}
        #$html .= "</table>";

        $html = "<div style='width:$w; height:$h; border:0px;marging:0px;padding:0px;' >";
        if ($v2 >0) {$html .= "<div style='width:$v2; height:$h; border:0px;marging:0px;padding:0px;background-color:$color2; float:right;'><img alt='$label' title='$label' src=/spc.gif width=$v2 height=$h style='border:0px;marging:0px;padding:0px;'hspace=0 vspace=0 border=0></div>";}
        if ($v1 >0) {$html .= "<div style='width:$v1; height:$h; border:0px;marging:0px;padding:0px;background-color:$color1; float:right;'><img alt='$label' title='$label' src=/spc.gif width=$v1 height=$h style='border:0px;marging:0px;padding:0px;'hspace=0 vspace=0 border=0></div>";}
        $html .= "</div>";

        return $html;
}
sub template_error() {
	local($title,$msg) = @_;
	&template_start();
	print "<br><br><div style='margin-left:50px;'>".template_error_box($title,$msg)."</div>";
	&template_end();
}
sub template_error_box(){
	local($title,$msg) = @_;
	local($out);
	$out = qq[
	<div class=clear style="border:1px solid #c0c0c0; background: yellow; padding:10px;">
		<table border=0 colspan=0 cellpadding=0 cellspacing=0 ><tr>
		<td valign=top>
			<img src=/icons/cancel.png vspace=0 hspace=0 style="margin-right:10px;">
		</td>
		<td valign=top>
			<span style="margin:0; padding:1; border:0; font-family:'Trebuchet MS','Lucida Grande',Arial,Helvetica; font-weight : bold;color : #000000;font-size : 20px;line-height: 80%; margin-bottom:20px;">$title</span><br>
			$msg
		</td>
		</tr></table>
	</div>
	];
	return $out;
}
sub template_print(){
    my ($template_file,%template_data) = @_;
    my ($buf,$n,$v,$tmp1,$tmp2,%hash,$i,$in);
    #
    # HACK: transform old data format to new format in case old code still send data in old format
	if (exists($template_data{dic})){
    	foreach $n (keys %{$template_data{dic}}){
    		$template_data{$n} = $template_data{dic}{$n};	
    	}
    	delete($template_data{dic});
    } 
    #
    $template_file = "$template_folder/$template_file";
    unless(-e $template_file) {print "Content-type: text/html\n\nI cannot found template file $template_file\n";return}
    my $template = HTML::Template::Expr->new(filename => $template_file, die_on_bad_params=>0, strict=>0, vanguard_compatibility_mode=>1);
	#
	# ---------------------
	# transform data
	# ---------------------
	# transform my freak template hash (only 2 deep inside) into state of art template data
	# my hash and code are not beautifull, but at least its toooo fucking easy to populate data :) 
	foreach $root_name (keys %template_data){
		# ---------------------
		# root
		# ---------------------
		$root_value = $template_data{$root_name};
		if (substr($root_value,0,4) eq "HASH") {
			#
			#
			# ---------------------
			# loop deep 1
			# ---------------------
			my @loop_1_array;
			foreach $loop_1_index (sort{$a <=> $b} keys %{$template_data{$root_name}}) {
				my %loop_1_hash;
				foreach $loop_1_name (keys %{$template_data{$root_name}{$loop_1_index}}) { 
					$loop_1_value = $template_data{$root_name}{$loop_1_index}{$loop_1_name};
					if (substr($loop_1_value,0,4) eq "HASH") {
						#
						# ---------------------
						# loop deep 2
						# ---------------------
						my @loop_2_array;
						foreach $loop_2_index (sort{$a <=> $b} keys %{$template_data{$root_name}{$loop_1_index}{$loop_1_name}}) {
							my %loop_2_hash;
							foreach $loop_2_name (keys %{$template_data{$root_name}{$loop_1_index}{$loop_1_name}{$loop_2_index}}) { 
								$loop_2_value = $template_data{$root_name}{$loop_1_index}{$loop_1_name}{$loop_2_index}{$loop_2_name};
								$loop_2_hash{$loop_2_name} =  $loop_2_value;
							}
							$loop_2_hash{loop_index} = $loop_2_index;
							push(@loop_2_array, \%loop_2_hash);
						}
						$loop_1_hash{$loop_1_name} = \@loop_2_array;
						# ---------------------
						# loop deep 2
						# ---------------------
						#
					} else {
						$loop_1_hash{$loop_1_name} =  $loop_1_value;
					}
				}
				$loop_1_hash{loop_index} = $loop_1_index;
				push(@loop_1_array, \%loop_1_hash);
			}
			$template->param($root_name => \@loop_1_array);	
			# ---------------------
			# loop deep 1
			# ---------------------
			#
		} else {
			$template->param($root_name => $root_value);
		}
	}
	if (substr("\U$template_file",-4,4) eq ".XML") {
	    &cgi_hearder_xml();	
	} elsif (substr("\U$template_file",-3,3) eq ".js") {
		print "Content-type: text/html\n\n";
	} else {
	    &cgi_hearder_html();
	}
    print $template->output();
}
sub OLD_template_print(){
    my ($template_file,%template_data) = @_;
    my ($buf,$n,$tmp1,$tmp2,%hash);
    $template_file = $template_folder.$template_file;
    unless(-e $template_file) {print "Content-type: text/html\n\nNo file $template_file\n";return}
    my $template = HTML::Template->new(filename => $template_file, die_on_bad_params=>0, strict=>0, vanguard_compatibility_mode=>1);
    foreach(sort keys %{$template_data{dic}}) {
	$template->param($_ => $template_data{dic}{$_} );
    }
    &cgi_hearder_html();
    print $template->output();
}
#------------------------
#
#------------------------
# generic perl library
#------------------------
sub get_today(){
	local($my_time)=@_;
	local (%out,@mes_extenso,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	if ($my_time eq "") {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime(time);
	} else {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime($my_time);
	}
	if ($year < 1000) {$year+=1900}
	$mon++;
	$out{DAY}		= $mday;
	$out{MONTH}		= $mon;
	$out{YEAR}		= $year;
	$out{HOUR}		= $hour;
	$out{MINUTE}	= $min;
	$out{SECOND}	= $sec;
	$out{DATE_ID}	= substr("0000".$year,-4,4) . substr("00".$mon,-2,2) . substr("00".$mday,-2,2);
	$out{TIME_ID}	= substr("00".$hour,-2,2) . substr("00".$min,-2,2) . substr("00".$sec,-2,2);
	$out{DATE_TO_PRINT} = &format_date($out{DATE_ID});
	$out{TIME_TO_PRINT} = substr("00".$hour,-2,2) . ":" . substr("00".$min,-2,2);
	return %out;
}
sub format_date(){
	local($in)=@_;
	local($out,$tmp1,$tmp2,@mes_extenso);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	@mes_extenso = qw (ERROR Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	if (length($in) eq 8) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4);
	} elsif (length($in) eq 14) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4)  ." at ".substr($in,8,2).":".substr($in,10,2) ;
	} else {
		$tmp1=substr($in,4,2);
		$tmp1++;$tmp1--;
		$out = (@mes_extenso)[$tmp1] . ", " .substr($in,0,4);
	}
	return $out;
}
sub clean_str() {
  #limpa tudo que nao for letras e numeros
  local ($old,$extra1,$extra2)=@_;
  local ($new,$extra,$i);
  $old=$old."";
  $new="";
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_.".$extra1; 		# new default
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_. @".$extra1; 	# using old default to be compatible with old cgi
  if ($extra1 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra2;}
  if ($extra2 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra1;}
  if ($extra1 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $new;
}
sub clean_int() {
  #limpa tudo que nao for letras e numeros
  local ($old)=@_;
  local ($new,$pre,$i);
  $pre="";
  $old=$old."";
  if (substr($old,0,1) eq "+") {$pre="+";$old=substr($old,1,1000);}
  if (substr($old,0,1) eq "-") {$pre="-";$old=substr($old,1,1000);}
  $new="";
  $caracterok="1234567890";
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $pre.$new;
}
sub clean_float() {
	local ($old)=@_;
	local ($new,$n1,$n2);
	if (index($old,".") ne -1) {
		($n1,$n2) = split(/\./,$old);
		$new = &clean_int($n1).".".&clean_int($n2);
	} else {
		$new = &clean_int($old);
	}
	return $new;
}
sub clean_html {
  local($trab)=@_;
  local($id,@okeys);
  @okeys=qw(b i h1 h2 h3 h4 h5 ol ul li br p B I H1 H2 H3 H4 H5 OL UL LI BR P);
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/<$id>/[$id]/g;
    $trab=~ s/<\/$id>/[\/$id]/g;
  }
  $trab=~ s/</ /g;
  $trab=~ s/>/ /g;
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/\[$id\]/<$id>/g;
    $trab=~ s/\[\/$id\]/<\/$id>/g;
  }
  return $trab;
}
sub is_numeric() {
	local($num) = @_;
	$num = trim($num);
	$p1 = "";
	$p1 = (substr($num,0,1) eq "-") ? "-" : $p1;
	$p1 = (substr($num,0,1) eq "+") ? "+" : $p1;
	$p0 = ($p1 eq "") ? $num : substr($num,1,1000);
	$p5="";
	if (index($p0,".")>-1) {
		($p2,$p3,$p4) = split(/\./,$p0);
		$p2 =~ s/[^0-9]/$p5/eg;
		$p3 =~ s/[^0-9]/$p5/eg;
		if ( ("$p1$p2.$p3" eq $num) && ($p4 eq "") ){return 1} else {return 0}
	} else {
		$p0 =~ s/[^0-9]/$p5/eg;
		if ("$p1$p0" eq $num) {return 1} else {return 0}
	}
}
sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}
sub format_number {
	local $_  = shift;
	local $dec = shift;
	#
	# decimal 2 its a magic number.. 2 decimals but more decimals for small numbers
	if (!$dec) {
		$dec="%.0f";
	} elsif ($dec eq 2) {
		$dec="%.2f";
		if($_<0.05) 		{$dec="%.3f"}
		if($_<0.005) 		{$dec="%.4f"}
		if($_<0.0005) 		{$dec="%.5f"}
		if($_<0.00005) 		{$dec="%.7f"}
		if($_<0.000005) 	{$dec="%.8f"}
		if($_<0.0000005) 	{$dec="%.9f"}
		if($_<0.00000005) 	{$dec="%g"}
	} else {
		$dec="%.".$dec."f";
	}
	$_=sprintf($dec,$_);
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}
sub format_time {
        local ($sec) = @_;
        local ($out,$min,$hour,$tmp);
        $sec = int($sec);
        if ($sec < 60) {
                $out = substr("00$sec",-2,2)."s";
                $out = $sec."s";
        } elsif ($sec < (60*60) ) {
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $min."m ".$sec."s";
        } else {
                $hour = int($sec/(60*60));
                $sec = $sec - ($hour*(60*60));
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = $hour."h ".substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $hour."h ".$min."m ".$sec."s";
        }
        return $out;
}
sub format_time_gap {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days,%tmpd);
        %d = &get_today($time);
        $sec = int(time-$time);
        if ($sec < 60) {
            $out = "$sec seconds ago";
        } elsif ($sec < (60*60) ) {
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$min minutes ago";
        } elsif ($sec < (60*60*6))  {
            $hour = int($sec/(60*60));
            $sec = $sec - ($hour*(60*60));
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$hour hours ago";
        } elsif ($sec < (60*60*24*60))  {
	    %tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY} $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        } else {
	    %tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY}/".substr($tmpd{YEAR},-2,2)." $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        }
        return $out ;
}
sub format_time_time {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days);
        %d = &get_today($time);
        return "$d{DATE_TO_PRINT} $d{TIME_TO_PRINT}" ;
}
sub check_email() {
  local ($old_email)=@_;
  local ($tmp1,$tmp2,$tmp2,$email,$ok);
  ($tmp1,$tmp2,$tmp3)=split(/\@/,$old_email);
  $tmp1 = &clean_str($tmp1,"._-","MINIMAL");
  $tmp2 = &clean_str($tmp2,"._-","MINIMAL");
  $email = "$tmp1\@$tmp2";
  $ok = 1;
  if (index($email,"@") eq -1) 	{$ok=0;}
  if (index($email,".") eq -1) 	{$ok=0;}
  if ($tmp3 ne "") 				{$ok=0;}
  if ($email ne $old_email) 	{$ok=0;}
  return $ok
}
sub format_dial_number() {
	my($in) = @_;
	my($out,$length);
	$in=&clean_int(substr($in,0,100));
	$out=$in;
	$length=length($in);
	if ($length eq 5) {
		$out = substr($in,0,2)."-".substr($in,2,3);
	} elsif ($length eq 6) {
		$out = substr($in,0,3)."-".substr($in,3,3);
	} elsif ($length eq 7) {
		$out = substr($in,0,3)."-".substr($in,3,4);
	} elsif ($length eq 8) {
		$out = substr($in,0,4)."-".substr($in,4,4);
	} elsif ($length eq 9) {
		$out = "(".substr($in,0,2).") ".substr($in,2,3)."-".substr($in,5,3);
	} elsif ($length eq 10) {
		$out = "(".substr($in,0,3).") ".substr($in,3,3)."-".substr($in,6,4);
	} elsif ($length eq 11) {
		$out = substr($in,0,1)." (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
	} elsif ($length eq 12) {
		$out = substr($in,0,2)." (".substr($in,2,3).") ".substr($in,5,3)."-".substr($in,8,4);
	}
	return($out)
}
sub multiformat_phone_number_check_user_input(){
	my($in) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	my($flag,$number_e164,$country);
	if (trim($in) eq "") {return ("EMPTY","UNKNOWN",$in);}

	$tmp = "\U$in";
	unless($tmp =~ m/[A-Z]/) {

		#
		# numeric.. lets check e164
		($flag,$number_e164,$country) = &multilevel_check_E164_number(&clean_int($in));
		if ($flag eq "USANOAREACODE") {
			return ("OK","E164","1$number_e164");
		} elsif ($flag eq "UNKNOWNCOUNTRY") {
			return ("UNKNOWNCOUNTRY","E164",$in);
		} elsif ($flag eq "OK") {
			return ("OK","E164",$number_e164);
		} else {
			return ("ERROR","E164",$in);
		}
	} else {
		# 
		# alpha, lets clean skype
		if (index($in,":") ne -1){	
			($tmp1,$tmp2) = split(/\:/,$in);$in = $tmp2; 
		}
		$tmp = &trim($in);
		$tmp1 = &clean_str($tmp,"-_.","MINIMAL");
		if ( ($tmp1 eq $tmp) && (length($tmp1)>=6) && (length($tmp1)<=32) ) {
			return ("OK","SKYPE",$tmp);
		} else {
			return ("ERROR ($in) ($tmp) ($tmp1) (".length($tmp1).") ","SKYPE",$in);
		}
	}
}
sub multiformat_phone_number_format_for_user(){
	my($in,$format_type) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	if ($in eq "") {return "";}
	if (&clean_int($in) eq $in){
		return &format_E164_number($in,$format_type);
	} else {
		return "Skype: $in";
	}
}
sub format_E164_number() {
	my($in,$format_type) = @_;
	my($out,%hash,$contry,$tmp);
	#
	#
	if ($in eq "") {return ""}
	#
	# get country list
	if ($app{country_buffer} eq "") {
	    %hash = &database_select_as_hash("select code,name from country ");
	    $app{country_buffer} = "|";
		$app{country_max_length} = 0;
	    foreach (keys %hash) {
			$app{country_buffer} .= "$_|";
			$app{country_max_length} = (length($_)>$app{country_max_length}) ? length($_) : $app{country_max_length};
		}
	}
	$country = "";
	foreach $tmp (1..$app{country_max_length}) {
		$tmp1 = substr($in,0,$tmp);
		if (index($app{country_buffer},"|$tmp1|") ne -1) {$country = $tmp1;}
	}
	$out = $in;
	if ($format_type eq "E164") {
		if ($country eq "") {
			$out = "+$in";
		} elsif ($country eq "1") {
			$out = "+1 (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "+55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "+$country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} elsif ($format_type eq "USA") {
		if ($country eq "") {
			$out = "+$in";
		} elsif  ( ($country eq "1") && (length($in) eq 11)) {
			$out = "(".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "011 55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "011 $country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} else {
	}
	return $out;
}
sub format_key_code(){
	local($in)=@_;
	local($t,$t1,$t2,$o,$c,$l,@a);
	$c = 0;
	$l = 1;
	$o = "";
	@a = ();
	while($l eq 1) {
		$t1 = trim(substr($in,-3,3));
		$t2 = trim(substr($in,0,-3));
		@a = (substr("0000$t1",-3,3),@a);
		if ($t2 eq "") {$l=0}
		$c++; if ($c>20){last}
		$in = $t2;
	}
	$o = join("-",@a);
	return $o;
}
sub format_pin(){
	local($in)=@_;
	local($t,$t1,$t2,$out,$c,$l,@a);
	$out=$in;
	if (length($in) eq 8){
		#$out = substr($in,0,3)."-".substr($in,3,2)."-".substr($in,5,3);
		$out = substr($in,0,2)."-".substr($in,2,2)."-".substr($in,4,4);
	}
	return $out;
}
sub format_trim_name(){
	local($in,$flag) = @_;
	local($out,$w);
	$out=$in;
	#
	# hack: show all names with no obfuscate
	$flag = 0;
	#
	if ($flag eq 1) {
	    $out = "";
	    foreach $w (split (/ +/,$in)){
		if ($w eq "") {next}
		$out .= (length($w)>2) ? substr("\U$w",0,1)."**** " : "$w ";
	    }
	}
	return $out;
}
#------------------------

