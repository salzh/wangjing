#!/usr/bin/perl
$|=1;$!=1; # disable buffer 
use File::Copy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use XML::Simple;
use Logger::Syslog;
$DataHash_folder	= "/home/neyfrota/Projetos/www.owsline.com/data/";
$DataText_folder	= "/home/neyfrota/Projetos/www.owsline.com/data/";
return 1;

#
#------------------------
# data load/save
#------------------------
sub DataHash_Load(){
	#
	# limpa, inicia, pega os dados
	local($file) = @_;
	local($buf,%data,$xml);
	local($n1,$v1,$n2,$v2,$n3,$v3,$n4,$v4,$tmp,$tmp1,$tmp2);
	%data = ();
	$file = &clean_str($file,"MINIMAL","_-");
	if ($file eq "") {return %data}
	$file = "$DataHash_folder/$file".".xml";
	#
	# le o arquivo 
	$buf = "";
	open(DataText_Load_IN,$file);
	while (<DataText_Load_IN>){$buf .= $_;}
	close(DataText_Load_IN);
	#
	# bota no obj xml
	if (trim($buf) eq "") {return %data}
	$xml = XMLin($buf);
	#
	# reorganiza os dados em formato hash (mais facil pra mim de usar)
	# o certo era fazer state-of-art com deep infinito, mas pra 
	# acelerar (tenho pesquisar pra isso), vou fazer tosco em 
	# 3 niveis so (hardcoded) copiand o codigo mesmo.. 
	# um dia volto e acerto :) 
	# 
	# nivel 1 
	foreach $n1 (keys (%{$xml})) {
		$v1 = $xml->{$n1};
		if (ref($v1) eq "HASH") {
				# 
				# nivel 2 
				foreach $n2 (keys (%{$v1})) {
					$v2 = $v1->{$n2};
					if (ref($v2->{$n2}) eq "HASH") {
							# 
							# nivel 3 
							foreach $n3 (keys (%{$v2})) {
								$v3 = $v2->{$n3};
								if (ref($v3) eq "HASH") {
										# 
										# nivel 4 
										foreach $n4 (keys (%{$v3})) {
											$v4 = $v3->{$n4};
											if (ref($v4) eq "HASH") {
											} elsif (ref($v4) eq "ARRAY") {
											} else {
												$data{$n1}{$n2}{$n3}{$n4} = $v4;
											}
										}
										#
								} elsif (ref($v3) eq "ARRAY") {
								} else {
									$data{$n1}{$n2}{$n3} = $v3;
								}
							}
							#
					} elsif (ref($v2->{$n2}) eq "ARRAY") {
					} else {
						$data{$n1}{$n2} = $v2;
					}
				}
				#
		} elsif (ref($v1) eq "ARRAY") {
		} else {
			$data{$n1}=$v1;
		}
	}
	#
	return %data;
}
sub DataHash_Save(){
	#
	# inicia, pega dados
	local($file,%data) = @_;
	local($buf,$xml);
	local($n1,$v1,$n2,$v2,$n3,$v3,$n4,$v4,$tmp,$tmp1,$tmp2);
	#
	# check file
	$file = &clean_str($file,"MINIMAL","_-");
	if ($file eq "") {return 0}
	$file = "$DataHash_folder/$file".".xml";
	#
	# todo: limpar o hash. 
	#
	# paga %data e monta o xml.
	# poderia aprender como criar o objeto xml e imput os dados
	# poderia fazer recursivopra ter menos codigo.
	# mas vou fazer tosco, na mao, hardcoded com 4 niveis de hash so
	# um dia com calma vejo isso certinho :) [nunca né? heheheh]
	#
	$xml = "";
	#
	# ===== nivel 1 ===== 
	foreach $n1 (sort keys %data) {
		$v1 = $data{$n1};
		if (ref($v1) eq "HASH") {
			$xml .= qq[<$n1>\n];
				#
				# ===== nivel 2 ===== 
				foreach $n2 (sort keys %{$data{$n1}}) {
					$v2 = $data{$n1}{$n2};
					if (ref($v2) eq "HASH") {
						$xml .= qq[\t<$n2>\n];
							#
							# ===== nivel 3 ===== 
							foreach $n3 (sort keys %{$data{$n1}{$n2}}) {
								$v3 = $data{$n1}{$n2}{$n3};
								if (ref($v3) eq "HASH") {
									$xml .= qq[\t\t<$n3>\n];
										#
										# ===== nivel 4 ===== 
										foreach $n4 (sort keys %{$data{$n1}{$n2}{$n3}}) {
											$v4 = $data{$n1}{$n2}{$n3}{$n4};
											if (ref($v4) eq "HASH") {
											} elsif (ref($v4) eq "ARRAY") {
											} else {
												$xml .= qq[\t\t\t<$n4>$v4</$n4>\n];
											}
										}
										# ==================== 
										#
									$xml .= qq[\t\t</$n3>\n];
								} elsif (ref($v3) eq "ARRAY") {
								} else {
									$xml .= qq[\t\t<$n3>$v3</$n3>\n];
								}
							}
							# ==================== 
							#
						$xml .= qq[\t</$n2>\n];
					} elsif (ref($v2) eq "ARRAY") {
					} else {
						$xml .= qq[\t<$n2>$v2</$n2>\n];
					}
				}
				# ==================== 
				#
			$xml .= qq[</$n1>\n];
		} elsif (ref($v1) eq "ARRAY") {
		} else {
			$xml .= qq[<$n1>$v1</$n1>\n];
		}
	}
	# ==================== 
	#
	#
	# grava o resultado final
	open(DataText_Load_OUT,">$file");
	print DataText_Load_OUT "<data>\n$xml</data>";
	close(DataText_Load_OUT);
	return 1;
}
sub DataHash_IsSameContent(){
	local($file1,$file2) = @_;
	local($tmp1,$tmp2,$tmp);
	$file1 = &clean_str($file1,"MINIMAL","_-");
	$file2 = &clean_str($file2,"MINIMAL","_-");
	if ($file1 eq "") {return -1}
	if ($file2 eq "") {return -2}
	$file1 = "$DataHash_folder/$file1".".xml";
	$file2 = "$DataHash_folder/$file2".".xml";
	$tmp1 = `/usr/bin/md5sum $file1 2>/dev/null `;
	$tmp1 = (index($tmp1,"No such file or directory") eq -1) ? substr($tmp1,0,32) : "";
	$tmp2 = `/usr/bin/md5sum $file2 2>/dev/null `;
	$tmp2 = (index($tmp2,"No such file or directory") eq -1) ? substr($tmp2,0,32) : "";
	return ( ($tmp1 ne "") && ($tmp1 eq $tmp2) ) ? 1 : 0;
}
sub DataHash_GetList(){}
sub DataText_Load(){
	local($file) = @_;
	local($buf);
	$file = &clean_str($file,"MINIMAL","_-");
	if ($file eq "") {return ""}
	$file = "$DataText_folder/$file".".txt";
	$buf = "";
	open(DataText_Load_IN,$file);
	while (<DataText_Load_IN>){$buf .= $_;}
	close(DataText_Load_IN);
	return $buf;
}
sub DataText_Save(){
	local($file,$buf) = @_;
	$file = &clean_str($file,"MINIMAL","_-");
	if ($file eq "") {return 0}
	$file = "$DataText_folder/$file".".txt";
	open(DataText_Load_OUT,">$file");
	print DataText_Load_OUT $buf;
	close(DataText_Load_OUT);
	return 1;
}
sub DataText_IsSameContent(){
	local($file1,$file2) = @_;
	local($tmp1,$tmp2,$tmp);
	$file1 = &clean_str($file1,"MINIMAL","_-");
	$file2 = &clean_str($file2,"MINIMAL","_-");
	if ($file1 eq "") {return -1}
	if ($file2 eq "") {return -2}
	$file1 = "$DataText_folder/$file1".".txt";
	$file2 = "$DataText_folder/$file2".".txt";
	$tmp1 = `/usr/bin/md5sum $file1 2>/dev/null `;
	$tmp1 = (index($tmp1,"No such file or directory") eq -1) ? substr($tmp1,0,32) : "";
	$tmp2 = `/usr/bin/md5sum $file2 2>/dev/null `;
	$tmp2 = (index($tmp2,"No such file or directory") eq -1) ? substr($tmp2,0,32) : "";
	return ( ($tmp1 ne "") && ($tmp1 eq $tmp2) ) ? 1 : 0;
}
sub DataText_GetList(){}

