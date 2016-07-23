#!/usr/bin/perl
=pod
	Version 1.0
	Developed by salzh
	Contributor(s):
	zhong weixiang<zhongxiang721@gmail.com>
=cut


require "/salzh/salzh/outbound/lib/default.include.pl";



use JSON; # to install, # sudo cpan JSON
$json_engine	= JSON->new->allow_nonref;



sub genuuid () {
	@char = (0..9,'a'..'f');
	$size = int @char;
	local $uuid = '';
	for (1..8) {
		$s = int rand $size;
		$uuid .= $char[$s];
	}
	$uuid .= '-';
	for (1..4) {
		$s = int rand $size;
		$uuid .= $char[$s];
	}
	$uuid .= '-';
	for (1..4) {
		$s = int rand $size;
		$uuid .= $char[$s];
	}
	$uuid .= '-';
	for (1..4) {
		$s = int rand $size;
		$uuid .= $char[$s];
	}
	$uuid .= '-';
	
	for (1..12) {
		$s = int rand $size;
		$uuid .= $char[$s];
	}
	
	return $uuid;	
}



sub Array2Json() {
	local(@jason_data) = @_;
	# hack: error.code need be a numeric if value is 0
	#if ( exists($jason_data{error}) ){
	#	if ($jason_data{error}{code} == "0"){
	#		$jason_data{error}{code} = 0;
	#	}
	#}
	my $json_data_reference = \@jason_data;
	my $json_data_text		= $json_engine->encode($json_data_reference);
	return $json_data_text;
}


# ==============================================
# json/response libs
# ==============================================
sub Json2Hash(){
	local($json_plain) = @_;
	local(%json_data);
	my %json_data = ();
	if ($json_plain ne "") {
		local $@;
		eval {
			$json_data_reference	= $json_engine->decode($json_plain);
		};
		
		if ($@) {warn $@}
		%json_data			= %{$json_data_reference};
	}
	return %json_data;
}
sub Hash2Json(){
	local(%jason_data) = @_;
	# hack: error.code need be a numeric if value is 0
	#if ( exists($jason_data{error}) ){
	#	if ($jason_data{error}{code} == "0"){
	#		$jason_data{error}{code} = 0;
	#	}
	#}
	my $json_data_reference = \%jason_data;
	my $json_data_text		= $json_engine->encode($json_data_reference);
	return $json_data_text;
}


sub t() {
        $now = `date`;
        $now =~ s/\n//g;

        return $now;
}

1;
