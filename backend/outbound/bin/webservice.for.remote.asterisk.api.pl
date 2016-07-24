#!/usr/bin/perl
require "/usr/local/owsline/lib/default.include.pl";
use Mojolicious::Lite;
use Data::Dumper;




# ==================================================
# check permission
# ==================================================
#under sub {
#	my $self = shift;
#	return 1 if $self->req->headers->header('X-Bender');
#	$self->render(text => "");
#	return;
#};
# ==================================================



get '/test/' => sub {
	my $self	= shift;
	my $name	= $self->param('name');
	my $value	= $self->param('value');
	my $answer	= "name='$name'\nvalue='$value'";
	$self->render(text => $answer, format => 'txt');
};


# ==================================================
# /konference_list
# ==================================================
get '/konference_list/' => sub {
	# get data
	my $self			= shift;
	my $conference_id	= $self->param('conference_id');
	# clean data
	$conference_id		= &clean_str($conference_id,"MINIMAL");
	# action
	my $answer			= &asterisk_manager_command_simple("konference list $conference_id");
	$self->render(text => $answer, format => 'txt');
};
get '/setvar/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $name 	= $self->param('name');
	my $value	= $self->param('value');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$name		= substr(&clean_str($name,"URL"),0,1024);
	$value 		= substr(&clean_str($value,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	$status		= ($name eq "") ? "ERROR_INCORRECT_NAME" : $status;
	$status		= ($value eq "") ? "ERROR_INCORRECT_VALUE" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Setvar', Channel => $channel, Variable => $name, Value => $value);
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};

get '/getvar/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $name 	= $self->param('name');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$name		= substr(&clean_str($name,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	# action
	if ($status eq "") {
		%action = (Action => 'Getvar', Channel => $channel, Variable => $name);
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{PARSED}->{Value} || 0;
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};

get '/konference_kick/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Command', Command => "channel redirect $channel process_call"); #konference kickchannel $channel");
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};
get '/konference_listenervolume_up/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Command', Command => "konference listenervolume $channel up ");
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};
get '/konference_listenervolume_down/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Command', Command => "konference listenervolume $channel down ");
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};
get '/konference_talkvolume_up/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Command', Command => "konference talkvolume $channel up ");
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};
get '/konference_talkvolume_down/' => sub {
	# get data
	my $self	= shift;
	my $channel = $self->param('channel');
	my $debug	= $self->param('debug');
	my $status	= "";
	my %action 	= ();
	my %answer	= ();
	my $tmp 	= "";
	# clean data
	$channel 	= substr(&clean_str($channel,"URL"),0,1024);
	$debug		= ($debug eq 1) ? 1 : 0;
	# check
	$status		= ($channel eq "") ? "ERROR_INCORRECT_CHANNEL" : $status;
	# action
	if ($status eq "") {
		%action = (Action => 'Command', Command => "konference talkvolume $channel down ");
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
		$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	}
	$self->render(text => $status, format => 'txt');
};
get '/konference_stream_connect/' => sub {
	#
	# get data
	my $self			= shift;
	my $conference_id	= $self->param('conference_id');
	my $stream_server_ip= $self->param('stream_server_ip');
	my $debug			= $self->param('debug');
	my $status			= "";
	my %action 			= ();
	my %answer			= ();
	my %list 			= ();
	my $id				= "";
	my $tmp 			= "";
	my $tmp1			= "";
	my $tmp2			= "";
	#
	# clean data
	$conference_id		= &clean_str($conference_id,"MINIMAL");
	$stream_server_ip	= &clean_str($stream_server_ip,"MINIMAL",".:_-");
	#
	# basic check
	$status		= ($conference_id eq "") ? "ERROR_INCORRECT_CONFERENCE_ID" : $status;
	$status		= ($stream_server_ip eq "") ? "ERROR_INCORRECT_STREAM_SERVER_IP" : $status;
	#
	# check if already connected
	if ($status eq "") {
		$tmp1 = 0;
		%list = &app_konference_list("LOCAL",$conference_id);
		foreach $id (keys %list) {
			if ($list{$id}{type} eq "STREAM") { $tmp1++;}
		}
		if 		($tmp1 eq 	1) { $status = "ERROR_STREAM_ALREADY_CONNECTED" }
		elsif 	($tmp1 > 	1) { $status = "ERROR_MULTIPLE_STREAM_CONNECTED" }
		# 
		# disconnect if multiple streams
		if ($status eq "ERROR_MULTIPLE_STREAM_CONNECTED") {
			foreach $id (keys %list) {
				if ($list{$id}{type} eq "STREAM") {
					%action = (Action => 'Command', Command => "konference kickchannel $list{$id}{sip_channel}");
					&asterisk_manager_command(%action);
				}
			}
			$status = "";
		}
	}
	#
	# action
	if ($status eq "") {
		$tmp = "SIP/0000".$conference_id."\@$stream_server_ip:5060";
		%action = (
			Action => 'Originate',
			Channel => $tmp,
			Context => 'streaming',
			Exten => 1111,
			Priority => 1,
			Variable => [ "conference=$conference_id"],
			Async => 0
		);
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
	}
	$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
	$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	$self->render(text => $status, format => 'txt');
};
get '/konference_stream_disconnect/' => sub {
	#
	# get data
	my $self			= shift;
	my $conference_id	= $self->param('conference_id');
	my $debug			= $self->param('debug');
	my $status			= "";
	my %action 			= ();
	my %answer			= ();
	my %list 			= ();
	my $id				= "";
	my $tmp 			= "";
	#
	# clean data
	$conference_id		= &clean_str($conference_id,"MINIMAL");
	#
	# check
	$status		= ($conference_id eq "") ? "ERROR_INCORRECT_CONFERENCE_ID" : $status;
	#
	# action
	if ($status eq "") {
		%list = &app_konference_list("LOCAL",$conference_id);
		foreach $id (keys %list) {
			if ($list{$id}{type} eq "STREAM") {
				%action = (Action => 'Command', Command => "konference kickchannel $list{$id}{sip_channel}");
				&asterisk_manager_command(%action);
			}
		}
		$status = "OK";
	}
	#
	$self->render(text => $status, format => 'txt');
};
# ==================================================


get '/konference_recording_connect/' => sub {
	#
	# get data
	my $self			= shift;
	my $conference_id	= $self->param('conference_id');
	my $stream_server_ip= $self->param('stream_server_ip');
	my $debug			= $self->param('debug');
	my $status			= "";
	my %action 			= ();
	my %answer			= ();
	my %list 			= ();
	my $id				= "";
	my $tmp 			= "";
	my $tmp1			= "";
	my $tmp2			= "";
	#
	# clean data
	$conference_id		= &clean_str($conference_id,"MINIMAL");
	$stream_server_ip	= &clean_str($stream_server_ip,"MINIMAL",".:_-");
	#
	# basic check
	$status		= ($conference_id eq "") ? "ERROR_INCORRECT_CONFERENCE_ID" : $status;
	$status		= ($stream_server_ip eq "") ? "ERROR_INCORRECT_STREAM_SERVER_IP" : $status;
	#
	# check if already connected
	if ($status eq "") {
		$tmp1 = 0;
		%list = &app_konference_list("LOCAL",$conference_id);
		foreach $id (keys %list) {
			if ($list{$id}{type} eq "RECORDING") { $tmp1++;}
		}
		if 		($tmp1 eq 	1) { $status = "ERROR_RECORDING_ALREADY_CONNECTED" }
		elsif 	($tmp1 > 	1) { $status = "ERROR_MULTIPLE_RECORDING_CONNECTED" }
		# 
		# disconnect if multiple streams
		if ($status eq "ERROR_MULTIPLE_STREAM_CONNECTED") {
			foreach $id (keys %list) {
				if ($list{$id}{type} eq "RECORDING") {
					%action = (Action => 'Command', Command => "channel request hangup $list{$id}{sip_channel}");
					&asterisk_manager_command(%action);
				}
			}
			$status = "";
		}
	}
	#
	# action
	if ($status eq "") {
		$tmp = "SIP/2222".$conference_id."\@$stream_server_ip:5060";
		%action = (
			Action => 'Originate',
			Channel => $tmp,
			Context => 'streaming',
			Exten => 2222,
			Priority => 1,
			Variable => [ "conference=$conference_id"],
			Async => 0
		);
		$tmp = &asterisk_manager_command(%action);
		%answer = %{$tmp};
		$status  = $answer{Response};
	}
	$status .= ($debug ne 1) ? "" : "\n".Dumper(%action);
	$status .= ($debug ne 1) ? "" : "\n".Dumper(%answer);
	$self->render(text => $status, format => 'txt');
};
get '/konference_recording_disconnect/' => sub {
	#
	# get data
	my $self			= shift;
	my $conference_id	= $self->param('conference_id');
	my $debug			= $self->param('debug');
	my $status			= "";
	my %action 			= ();
	my %answer			= ();
	my %list 			= ();
	my $id				= "";
	my $tmp 			= "";
	#
	# clean data
	$conference_id		= &clean_str($conference_id,"MINIMAL");
	#
	# check
	$status		= ($conference_id eq "") ? "ERROR_INCORRECT_CONFERENCE_ID" : $status;
	#
	# action
	if ($status eq "") {
		%list = &app_konference_list("LOCAL",$conference_id);
		foreach $id (keys %list) {
			if ($list{$id}{type} eq "RECORDING") {
				%action = (Action => 'Command', Command => "channel request hangup $list{$id}{sip_channel}");
				&asterisk_manager_command(%action);
			}
		}
		$status = "OK";
	}
	#
	$self->render(text => $status, format => 'txt');
};



# ==================================================
# main loop
# ==================================================
app->start;
# ==================================================




# ==================================================
# templates
# ==================================================
__DATA__

@@ not_found.html.ep
error



