#!/opt/lampp/bin/perl
#A2B.pm
#2011-03-19 13:30:00 UTC+8

#$Id: A2B.pm 73 2011-03-23 07:32:06Z salzh $

package A2B;

use DBI;
use CGI::Simple( -upload );
use IO::File;
use HTTP::Date;
#use Template;
use strict;
use warnings;
use Asterisk::Manager;

sub new {
    my $class  = shift;
    my $self   = {};
    my $passwd = '';
    #my ($db, $host, $user, $passwd) = ('mya2billing', 'localhost', 'a2billinguser', 'a2billing);
    my $conffile  = '/etc/freepbx.conf';
    my $conf      = {};
    $conf         = _parse_a2b_conf($conffile);

    my $db   = $conf->{"\$amp_conf['AMPDBENAME']"} || 'asterisk';
    $db =~ s/[';]//g;
    my $host = $conf->{"\$amp_conf['AMPDBHOST']"} || 'localhost';
    $host =~ s/[';]//g;
    my $user = $conf->{"\$amp_conf['AMPDBUSER']"} || 'asteriskuser';
    $user =~ s/[';]//g;
    my $pass = $conf->{"\$amp_conf['AMPDBPASS']"} || 'amp109';
    $pass =~ s/[';]//g;
    $self->{'ami_user'} = 'dispatch';
    $self->{'ami_pass'} = 'dispatch123';
    $self->{'ami_host'} = '127.0.0.1';
    $self->{'ami_port'} = '5038';

    my $dbh;
    warn "DBI:mysql:database=$db;host=$host, $user, $pass\n";
    $dbh  = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $pass, {RaiseError => 0, AutoCommit => 1}) || return;
    $self->{conf}           = $conf;
    $self->{dbh}            = $dbh;
    $CGI::Simple::DISABLE_UPLOADS = 0;
    $CGI::Simple::POST_MAX        = 1_000_000_000;

    $self->{cgi}                  = CGI::Simple->new();
    my $LOG		= new IO::File;
    $LOG	   -> open(">> /tmp/a2b.log");
    $LOG	   -> autoflush(1);

    $self->{LOG} = $LOG;

    init_manager($self) || die "fail to create init manager";
    return bless( $self, $class );
}

sub init_dbh_cdr {
    my $self = shift;
    #my ($db, $host, $user, $pass) = ('asteriskcdrdb', 'localhost', 'asteriskuser', 'amp109');
    my $conffile  = '/etc/asterisk/cdr_mysql.conf';
    my $conf      = {};
    $conf         = _parse_a2b_conf($conffile);

    my $db   = $conf->{dbname} || 'asterisk';
    my $host = $conf->{hostname} || 'localhost';
    my $user = $conf->{user} || 'asteriskuser';
    my $pass = $conf->{password} || 'amp109';
    warn "DBI:mysql:database=$db;host=$host, $user, $pass\n";
    my $dbh = DBI->connect("DBI:mysql:database=$db;host=$host", $user, $pass, {RaiseError => 0, AutoCommit => 1}) || return;
    return $dbh;
}

sub init_manager {
	my $self = shift;
    my ($user, $secret, $host, $port) = @_;
	my $ami  = new Asterisk::Manager;
    $user   ||= $self->{ami_user};
    $secret ||= $self->{ami_pass};
    $host   ||= $self->{ami_host};
    $port   ||= $self->{ami_port};


	$ami->user($user);
	$ami->secret($secret);
	$ami->host($host);
    $ami->port($port);

	$ami->connect || return;
	warn "Success Connect to Asterisk manager: " . $user . "\n";

	$self->{ami} = $ami;


	return $ami;
}

sub dispatch {
    my $self   = shift;
    my $ttfile = shift || 'default.tt';
    my $var    = shift;
    my $args   = shift || {};


    $args->{INCLUDE_PATH} = "." unless $args->{INCLUDE_PATH};
    $args->{RELATIVE} = 1 unless defined $args->{RELATIVE};
    my $tt = Template->new($args);

    my $res;
    $tt->process($ttfile, $var, \$res) || die $tt->error();
        #die $res;
    return $res;
}

sub _parse_a2b_conf {
    my $file = shift;
    my $conf = {};
    #return $conf;
    if (!-e $file) {
        die "file=$file not exists\n";
    }

    open FH, $file || "die fail to open $file for reading: $!\n";
    while (<FH>) {
        next if /^[#;]/ || /^\s*$/;
        chomp;
        my ($k, $v) = split /\s*=\s*/, $_, 2;
        next if !$k;

        $conf->{$k} = (defined $v ? $v : '');
    }

    return $conf;
}

sub cgi {
    my $self = shift;
    return $self->{cgi};
}

sub session {
    my $self = shift;
    return $self->{session};
}

sub dbh {
    my $self = shift;
    return $self->{dbh};
}

sub ami {
    my $self = shift;
    return $self->{ami};
}

sub a2b_time2str {
    my $self = shift;
    my $time = shift;
    my $mode = shift;

    my @args = ();
    if (defined $time && $time ne '0') {
        if ($time =~ /\d-\d/) {
            return $time;
        }
        @args = localtime $time;
    } else {
        @args = localtime;
    }
    if (!$mode) {
        return sprintf("%02d-%02d-%02d %02d:%02d:%02d",
                $args[5]+1900, $args[4]+1, $args[3], $args[2], $args[1], $args[0]);
    } else {
        return sprintf("%02d-%02d-%02d", $args[5]+1900, $args[4]+1, $args[3]);
    }
}

#xxx-xx-xx xx:xx:xx to time (\d\d\d\d\d)
sub a2b_str2time {
    my $self = shift;
    my $date = shift || return '';
    my $zone = shift;

    return str2time($date, $zone) || 0;
}

sub sendcommand {
    my $self = shift;
    if (@_ % 2) {
        pop @_;
    }

    my $text = $self->{ami}->sendcommand(@_, 1);
    my $hash = {body => ''};
    $text   =~ s/\r//g;
    for my $line (split "\n", $text) {
        my ($k, $v) = $line =~ m/^(\w+?):\s*(.+)$/;
        if ($k) {
            $hash->{$k} = $v;
        } else {
            $hash->{body} .= "\n" if $hash->{body};
            $hash->{body} .= $line;
        }
    }
    return $hash;
}

sub log_debug {
    my $self = shift;
	my $type = shift || '';
	my $str  = shift || '';
    my $fh   = $self->{LOG};

	my @args = localtime;
	my $now  = sprintf("%02d-%02d-%02d %02d:%02d:%02d",
                $args[5]+1900, $args[4]+1, $args[3], $args[2], $args[1], $args[0]);

	print $fh "[$now][$type] -- $str\n";
}

1;
