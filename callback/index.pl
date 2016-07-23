#!/usr/bin/perl

#index.pl
#2011-03-19 13:30:00 UTC+8

#$Id: csv.pl 117 2011-03-30 04:16:31Z salzh $

use A2B;
use strict;
use warnings;
use HTTP::Date;
use JSON; # to install, # sudo cpan JSON
my $json_engine;

unless ($json_engine) {$json_engine = JSON->new->allow_nonref;}

my $a2b = A2B->new();
my $cgi = $a2b->cgi;
my $dbh = $a2b->dbh();
use YAML;
my $rate = 0.075;
my @ip   = qw //;
print $cgi->header(-charset => "UTF-8");

my $ip = $cgi->remote_addr();
validate_ip($ip)  || reply_error("IP=$ip NOT ALLOWED");

my $action = $cgi->param('action') || reply_error("No action defined");
my $id	   = $cgi->param('tid') || getid();
my $ChanDetail = get_allchannel_detail();
warn Dump($ChanDetail);
if ($action eq 'originate') {
	my $src = $cgi->param('src') || reply_error("src not defined");
	my $dst = $cgi->param('dst') || reply_error("dst not defined");
	my $s   = $cgi->param('mode') || 1;
	($src, $dst) = ($dst, $src) if $s == 2;

	my $sth = $dbh->prepare("insert into callback_spool (id, src, dst) values (?, ?, ?)");
	my $ar  = $sth-> execute($id, $src, $dst);
	if (!$ar) {
		print build_reply({status => 0, message => $sth->errstr});
		exit 0;
	}
	
	
	if (check_status($src) != 0) {
		print build_reply({status => 0, message => "$src is busy"});
                exit 0;
	}
	
	if (check_status($dst) != 0) {
                print build_reply({status => 0, message => "$dst is busy"});
                exit 0;
	}
	my $res = $a2b->sendcommand("action" => 'originate', 'channel' => "local/$src\@from-callback/n",
								"Context" => "from-callback", 'Exten' => "$dst", 'Priority' => '1', Async => '1',
								"callerid" => "$src", "Timeout" => 30000,  'Variable' => "__USERFIELD=$id,ACCOUNTCODE=$dst,__tid=$id");
	if ($res->{Response} ne 'Error') {
		print build_reply({status => 1, message => "call sent", tid=>$id});
	} else {
		print build_reply({status => 0, message => $res->{message}});
	}
	exit 0;
} elsif ($action eq 'hangup') {
	my $sth = $dbh -> prepare("select src,dst from callback_spool where id=?");
	$sth   -> execute($id);
	my $row = $sth->fetchrow_hashref;
	my $src = $row->{src} || '';
	if ($src) {
		my $chan = $ChanDetail->{CALLERID}{$src} || $ChanDetail->{CALLERID}{"0$src"};
		warn "try to hangup id=$id:src=$src:chan=$chan\n";
		hangup($chan);
	}

	print build_reply({status => 1, message => "hangup sent"});
	exit 0;
} elsif ($action eq 'getrecording') {
	my $dbh_cdr = $a2b->init_dbh_cdr() || reply_error("CDR DB ERROR");
 	my $uid = $cgi->param('uid');
	my $sth;
	if (!$uid) { 	
		$sth     = $dbh_cdr->prepare("select * from cdr where userfield=? and recordingfile!=''");
		$sth	   -> execute($id);
	} else {
		$sth     = $dbh_cdr->prepare("select * from cdr where uniqueid=? and recordingfile!=''");
                $sth       -> execute($uid);
	}
	warn $id;
	if ($sth->rows < 1) {
			print build_reply({status => 0, message => 'recording not found'});
			exit 0;
	}

	my $row = $sth->fetchrow_hashref();
	my $ret = get_recordfile($row->{calldate}, $row->{duration}, $row->{recordingfile});

	print build_reply( $ret);;

} elsif ($action eq 'viewstate') {
	my $sth = $dbh -> prepare("select src,dst from callback_spool where id=?");
	$sth   -> execute($id);
	my $row = $sth->fetchrow_hashref;
	my $src = $row->{src} || '';
	my $dst = $row->{dst} || '';
	warn "src=$src,dst=$dst";
	my $schan = $ChanDetail->{CALLERID}{$src} || $ChanDetail->{CALLERID}{"0$src"} || '';
	my $dchan = $ChanDetail->{CALLERID}{$dst} || $ChanDetail->{CALLERID}{"0$dst"} || '';
	warn "schan=$schan,dchan=$dchan";
	my $sfs	  = $ChanDetail->{CHAN}{$schan} || [];
	my $dfs   = $ChanDetail->{CHAN}{$dchan} || [];

	warn @$sfs;
	warn @$dfs;

	if (!$$sfs[4]) { #call end
		my $dbh_cdr = $a2b->init_dbh_cdr() || reply_error("CDR DB ERROR");
		my $sth     = $dbh_cdr->prepare("select * from cdr where userfield=? and (dst=? or dst like ?)");
		$sth	   -> execute($id, $src, "%$src");
		if ($sth->rows < 1) {
			print build_reply({status => 1, message => 'call is connecting...', srcstate => '0', srcduration => 0, srcfee => 0,
					 dststate => '0', dstduration => 0, dstfee => 0});
			exit 0;
		}
		my $row		= $sth->fetchrow_hashref;
		my $arg     = {status => 1, srcstate => '2', srcduration => $row->{billsec},
					   srcfee=> $rate* $row->{billsec} / 60};
		$arg       -> {dststate} = 2;

		$sth	   -> execute($id, $dst, "%$dst");
		if ($sth->rows < 1) {
			$arg->{dstduration} = 0;
			$arg->{dstfee}		= 0;
		} else {
			$row				= $sth->fetchrow_hashref;
			$arg->{dstduration} = $row->{billsec};
			$arg->{dstfee}		=  $rate* $row->{billsec} / 60;
		}
		print build_reply($arg);
		exit 0;
	}

	if ($$sfs[4] && $$sfs[4] ne 'Up') {
		print build_reply({status => 1, message => 'src is ringing', srcstate => '0', srcduration => 0, srcfee => 0,
					 dststate => '0', dstduration => 0, dstfee => 0});
		exit 0;
	}

	my $schaninf = get_channel_cdr_detail($schan);
	my $billsec  = $$sfs[10];
	if ($schaninf->{start} && $schaninf->{answer}) {
		$billsec -= $a2b->a2b_str2time($schaninf->{answer}) - $a2b->a2b_str2time($schaninf->{start});
	}

	my $arg	     = {srcstate => '1', srcduration => $billsec,
					srcfee => $rate*$billsec / 60};
	if ($$dfs[4] && $$dfs[4] ne 'Up') {
		$arg -> {status}    = 1;
		$arg->{dststate}    = 0;
		$arg->{dstduration} = 0;
		$arg->{dstfee}		= 0;

		print build_reply($arg);
		exit 0;
	}

	my $dchaninf = get_channel_cdr_detail($dchan);
	$billsec	 = $$sfs[10];
	if ($dchaninf->{start} && $dchaninf->{answer}) {
		$billsec -= $a2b->a2b_str2time($dchaninf->{answer}) - $a2b->a2b_str2time($dchaninf->{start});
	}

	$arg->{status}      = 1;
	$arg->{dststate}    = 1;
	$arg->{dstduration} = $billsec;
	$arg->{dstfee}		= $rate*$billsec / 60;

	print build_reply($arg);
	exit 0;
} elsif ($action eq 'sendshortcall') {
	my $src = $cgi->param('dest') || reply_error("src not defined");
	#my $dst = $cgi->param('dst') || reply_error("dst not defined");
	my $dst = '555';
	
	my $s   = $cgi->param('mode') || 1;
	($src, $dst) = ($dst, $src) if $s == 2;

	my $sth = $dbh->prepare("insert into callback_spool (id, src, dst) values (?, ?, ?)");
	my $ar  = $sth-> execute($id, $src, $dst);
	if (!$ar) {
		print build_reply({status => 0, message => $sth->errstr});
		exit 0;
	}

	my $res = $a2b->sendcommand("action" => 'originate', 'channel' => "local/$src\@from-internal/n",
								"Application" => "hangup", 'Data' => "",  Async => '1',
								"callerid" => "$src", "Timeout" => 2000,  'Variable' => "USERFIELD=$id|ACCOUNTCODE=$dst");
	if ($res->{Response} ne 'Error') {
		print build_reply({status => 1, message => "call sent", tid=>$id});
	} else {
		print build_reply({status => 0, message => $res->{message}});
	}
	exit 0;
} else {
	reply_error("action=$action not defined, only (originate, hangup, viewstate) supported now");
}

sub validate_ip {
	return 1;
}

sub reply_error {
	print build_reply({status => 0, message => shift});

	exit 0;
}

=pod
sub build_reply {
	my $arg    = shift || {};

	my $retstr =  "<response><status>" . ($arg->{status} ||0) . "</status>" .
				   "<message>" . ($arg->{message} || '') . "</message>";

	while (my ($k, $v) = each %$arg) {
		next if !$k || $k eq 'status' || $k eq 'message';
		$retstr .= "<$k>" . (defined $v ? $v : '') . "</$k>";
	}

	$retstr   .= "</response>";

	return $retstr;
}

=cut
sub build_reply {
	my $arg    = shift || {};
	my $hash   = {};
	my $retstr =  "<response><status>" . ($arg->{status} ||0) . "</status>" .
				   "<message>" . ($arg->{message} || '') . "</message>";
	
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

sub hangup {
	my $chan = shift || return 1;

	$a2b->sendcommand('action' => 'hangup', 'channel' => "$chan");
	return 1;
}

sub get_allchannel_detail {
	my $hash  = {};
	my $res	  = $a2b->sendcommand('action' => 'command', 'command' => 'core show channels concise');
	my @lines = split "\n", $res->{body};

	for my $l (@lines) {
		warn $l;
		my @fields = split /!/, $l;

		if ($fields[7] && $fields[5] eq 'AppDial') { #outnum && AppDial
			$hash->{CHAN}{$fields[0]} = \@fields;
			$hash->{CALLERID}{$fields[7]}   = $fields[0];
		}
	}

	return $hash;
}

sub get_channel_cdr_detail {
	my $hash = {};
	my $chan = shift;

	my $pattern = '(start|answer)=(.+)$';

	my $res  = $a2b->sendcommand('action' => 'command', 'command' => "core show channel $chan");
	my @lines= split "\n", $res->{body};
	for my $l (@lines) {
		if ($l =~ /$pattern/) {
			$hash->{$1} = $2;
		}
	}

	return $hash;
}

sub getid {
	return time . int rand 9999;
}

sub get_recordfile {
    my $calldate = shift;
    my $duration = shift || 0;
    my $recordingfile = shift;
    #q-100-2001-20141223-215056-1419342656.1852.wav
    if ($recordingfile) {
        my ($dir, $src, $dst, $D, $t) = split /\-/, $recordingfile;
        my ($y, $m, $d) = $D =~ /(\d\d\d\d)(\d\d)(\d\d)/;
    
        my $s = -s "/var/spool/asterisk/monitor/$y/$m/$d/$recordingfile";

        return {file => "/spool/monitor/$y/$m/$d/$recordingfile", size => $s, status => 1};
    } else {
        return {status => 0, message => "not found recording dir"};
    }
}

sub get_recordfile2 {
    my $calldate = shift;
    my $duration = shift || 0;
    my $uniqueid = shift;

    #warn "try to get_recordfile by calldate=$calldate and uniqueid=$uniqueid\n";
	my ($date)   = $calldate  =~ /(\d\d\d\d\-\d\d\-\d\d)/g;
	my $st		 = str2time($calldate, "+0800");
	#warn $st;
    my $dir = "/var/spool/asterisk/monitor";
    my $f   = "";
    my $s   = 0;
	$date   =~ s/\-//g;
    $dir   .= "/$date";

    if (!-d $dir) {
        return {status => 0, message => "$dir not exsits"}
    }

    if ($uniqueid) {
        for my $file (glob "$dir/*") {
            next unless $file =~ /$uniqueid\.(gsm|wav)/i;
            $f  = $file;
            $s  = -s $file;
        }

    } elsif ($calldate) {
        for my $file (glob "$dir/*") {
            next if -d $file || $file !~ /\.(?: gsm|wav)/i;
            my @parts = split("-", $file,2);
            if ($file =~ /$st/ || ($file =~ /auto/ && $parts[1] >= $st && $parts[1] <= $st + $duration)) {
                $s    = -s $file;
                $s    = ($s > 10 * 1024 ? $s : 0);
                if ($s) {
                     $f = $file;
				} else {
					last;
				}
            }
        }
    }

	if ($f) {
		$f =~ s{/var/spool/asterisk}{/spool};
		return {file => "http://10.12.53.230" . $f, size => $s, status => 1};
	} else {
		return {status => 0, message => "not found recording dir=$dir time=$st"};
	}
}

sub check_status {
	my $ext = shift;
	my $res   = $a2b->sendcommand('action' => 'ExtensionState', 'Context' => 'ext-local', Exten => $ext);
	warn $res->{Status};
	
	return   $res->{Status} <= 0 ? 0 : $res->{Status} ;

}
