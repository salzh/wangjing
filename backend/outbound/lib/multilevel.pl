#!/usr/bin/perl
return 1;
#=======================================================
#
#------------------------
# multilevel api
#------------------------
sub multilevel_change_service_status_by_switch_on_data(){
	local($service_id,$switch_on_name) = @_;
	return &multilevel_service_status_change_if_need($service_id,$switch_on_name);
}
#------------------------
#
#------------------------
# rate mode (new and old api)
#------------------------
sub multilevel_rate_table_get(){
	local($number,$rate_table_id) = @_;
	local(%data,$sql,$sql_1,$sql_2,%hash,$i,$sub,$tmp,$tmp1,$tmp2,$tmp4);
	%data = ();
	$data{ok_to_use}			= 0;
    $data{number}				= $number;
    $data{number_type}			= "";
 	$data{number_length}		= length($data{number});
    $data{rate_table_id}		= $rate_table_id;
	$data{rate_id}				= "";
    $data{rate_number_prefix}	= "";
    $data{rate_is_peak} 		= 0;
    $data{rate_is_reduced} 		= 0;
	$data{rate_found}			= 0;
	$data{rate_prefix}			= "";
	$data{rate_country}			= "";
	$data{rate_areacode}		= "";
	$data{rate_name}			= "";
	$data{rate_resolution}		= 1;
	$data{rate_min_call_seconds}= 1;
	$data{rate_grace_seconds}	= 0;
	$data{rate_rate_per_call}	= 0;
	$data{rate_rate_per_minute}	= 0;
	$data{rate_max_call_seconds}= 0;
	$data{asterisk_string_raw}	= "";
	$data{asterisk_string}		= "";
	#
	# verifica se essa rate_tabela existe
    #
    # verifica se estamos em peak ou reduced time
    %today = &get_today();
    #$sql_1 	= "rateswitch_peak_". $today{WEEK_DAY} ."_". substr("00".$today{HOUR},-2,2);
    #$sql_2 	= "rateswitch_reduced_". $today{WEEK_DAY} ."_". substr("00".$today{HOUR},-2,2);
    #$sql 	= "select 1,1,$sql_1,$sql_2 from product where id='$data{product_id}' ";
    #%hash	= &database_select_as_hash($sql,"flag,is_peak,is_reduced");
    #$data{rate_is_reduced}	= ( ($hash{1}{flag} eq 1) && ($hash{1}{is_reduced} eq 1) ) ? 1 :  0;
    #$data{rate_is_peak}   	= ( ($hash{1}{flag} eq 1) && ($hash{1}{is_peak}    eq 1) ) ? 1 :  0;
    #$data{rate_is_reduced}	= ($data{rate_is_peak} eq 1) ? 0 : $data{rate_is_reduced};
    $data{rate_is_reduced}	= 0;
    $data{rate_is_peak}   	= 0;
    #
    # busca numero conforme o tipo
    if ($data{number} eq ""){
    	#
    	# sem numero, abortar
    } elsif (&clean_int($data{number}) eq $data{number}){
    	#
    	# busca numerica. Eh sip por default
	    $data{number_type} = "SIP";
	    #$sql = "SELECT 1,1,max(length(concat(prefix,country,areacode))) FROM product_rate_table_data where rate_id='$data{rate_table_id}' ";
	    $sql = "SELECT 1,1,max(length(query_search)) FROM product_rate_table_data where rate_id='$data{rate_table_id}' ";
	    %hash = &database_select_as_hash($sql,"flag,len");
	    if ($hash{1}{flag} eq 1) { $data{number_length} = ($data{number_length} > $hash{1}{len}) ? $hash{1}{len} : $data{number_length}; }
	    if ($data{number_length}>0) {
			foreach $i (1..$data{number_length}) {
				$sub = substr($data{number},0,$i);
				#$sql = "SELECT 1,1,id FROM product_rate_table_data where rate_id='$data{rate_table_id}' and concat(prefix,country,areacode) = '$sub' LIMIT 0,1";
				$sql = "SELECT 1,1,id FROM product_rate_table_data where rate_id='$data{rate_table_id}' and query_search = '$sub' LIMIT 0,1";
				%hash = &database_select_as_hash($sql,"flag,id");
				if ($hash{1}{flag} eq 1) {$data{rate_id} = $hash{1}{id}; $data{rate_number_prefix}=$sub;}
			}
	    }
    } else {
    	#
    	# busca nao numerica, por skype
	    $data{number_type} = "SKYPE";
		$sql = "SELECT 1,1,id FROM product_rate_table_data where rate_id='$data{rate_table_id}' and country = '9991' LIMIT 0,1";
		%hash = &database_select_as_hash($sql,"flag,id");
		if ($hash{1}{flag} eq 1) {$data{rate_id} = $hash{1}{id}; $data{rate_number_prefix}=$sub;}
    } 
    # busca tarifa pra esse destination
	#
	# verificas numeros bloqueados
	#$dst_block = "|sip:zenofon-server|16192127761|12153999293|16464344612|16464344613|16464344614|16464344615|16464344616|16464344617|16464344618|16464344619|16464344620|16464344621|16464344622|16464344623|16464344624|16464344625|16464344626|16464344627|16464344628|16464344629|16464344630|16464344631|16785376576|14108649137|16175351939|12162580292|13123486016|16142953007|12144160101|13137430146|17134015184|12014032079|17025833342|12135310063|13059086090|16154722025|17182909990|18474009651|12153999293|16022811146|16136759194|12027300310|8662575604|6464344632|6468736314|6468736324|6468736341|6468736342|6468736374|6468736394|6468736913|6468736914|6468736927|6468736928|6468736929|6468736934|";
	$dst_block = "|12012041847|12012041847|12027300310|12153999293|13059086090|13474643447|13477354411|16175351939|17182909990|17187058589|12014032079|19172849421|19172849422|19172849423|19172849425|19172849426|19172849427|19172849429|19172849430|19172849431|19172849432|19172849433|19172849434|19172849435|19172849436|19172849437|19172849438|19172849439|19172849440|19172849441|19172849442|19172849443|19172849445|19172849446|19172849447|19172849448|19172849449|19172849450|12012041154|12012041821|12012041822|12012041823|12012041824|12012041825|12012041826|12012041827|12012041828|12012041829|12012041830|12012041831|12012041832|12012041833|12012041834|12012041835|12012041836|12012041838|12012041839|12012041840|12012041841|12012041842|12012041843|12012041844|12012041845|12012041846|12012041847|18662575604|16464344612|16464344613|16464344614|16464344615|16464344616|16464344617|16464344618|16464344619|16464344620|16464344621|16464344622|16464344623|16464344624|16464344625|16464344626|16464344627|16464344628|16464344629|16464344630|16464344631|16464344632|16468736314|16468736324|16468736341|16468736342|16468736374|16468736394|16468736913|16468736914|16468736927|16468736928|16468736929|16468736934|";
	if ( index($dst_block ,"|$data{number}|") ne-1){
		$data{rate_id} 				= "";
		$data{rate_found}			= 0;
		$data{rate_number_prefix} 	= "";
		$data{ok_to_use} 			= 0;
		$data{rate_dst_block} 		= 1;
	}
	#
	# se achou, vamos agir
    if ($data{rate_id} ne "") {
		$tmp1 = 							"rate_per_call,rate_per_minute,max_call_seconds";
		$tmp1 = ($data{is_peak} eq 1) ? 	"rate_per_call_peak,rate_per_minute_peak,max_call_seconds_peak" : $tmp1;
		$tmp1 = ($data{is_reduced} eq 1) ?	"rate_per_call_reduced,rate_per_minute_reduced,max_call_seconds_reduced" : $tmp1;
		$sql = "SELECT 1,1,asterisk_string,prefix,country,areacode,name,resolution,min_call_seconds,grace_seconds,$tmp1 FROM product_rate_table_data where id = '$data{rate_id}' ";
		%hash = &database_select_as_hash($sql,"flag,asterisk_string,prefix,country,areacode,name,resolution,min_call_seconds,grace_seconds,rate_per_call,rate_per_minute,max_call_seconds");
		if ($hash{1}{flag} eq 1) {
			$data{rate_found}			= 1;
			$data{rate_prefix}			= $hash{1}{prefix};
			$data{rate_country}			= $hash{1}{country};
			$data{rate_areacode}		= $hash{1}{areacode};
			$data{rate_name}			= $hash{1}{name};
			$data{rate_resolution}		= $hash{1}{resolution};
			$data{rate_min_call_seconds}= $hash{1}{min_call_seconds};
			$data{rate_grace_seconds}	= $hash{1}{grace_seconds};
			$data{rate_per_call}		= $hash{1}{rate_per_call};
			$data{rate_per_minute}		= $hash{1}{rate_per_minute};
			$data{rate_max_call_seconds}= $hash{1}{max_call_seconds};
			$data{asterisk_string_raw}	= $hash{1}{asterisk_string};
			# limpa e confere os valores
			$data{rate_resolution}++;
			$data{rate_resolution}--;
			$data{rate_resolution} = ($data{rate_resolution} < 1) ? 1 : $data{rate_resolution};
			$data{rate_resolution} = ($data{rate_resolution} > 43200) ? 43200 : $data{rate_resolution};
			$data{rate_min_call_seconds}++;
			$data{rate_min_call_seconds}--;
			$data{rate_min_call_seconds} = ($data{rate_min_call_seconds} < 0) ? 0 : $data{rate_min_call_seconds};
			$data{rate_min_call_seconds} = ($data{rate_min_call_seconds} > 43200) ? 43200 : $data{rate_min_call_seconds};
			$data{rate_grace_seconds}++;
			$data{rate_grace_seconds}--;
			$data{rate_grace_seconds} = ($data{rate_grace_seconds} < 0) ? 0 : $data{rate_grace_seconds};
			$data{rate_grace_seconds} = ($data{rate_grace_seconds} > 43200) ? 43200 : $data{rate_grace_seconds};
			$data{rate_per_call}++;
			$data{rate_per_call}--;
			$data{rate_per_call} = ($data{rate_per_call} < 0) ? 0 : $data{rate_per_call};
			$data{rate_per_call} = ($data{rate_per_call} > 100) ? 100 : $data{rate_per_call};
			$data{rate_per_minute}++;
			$data{rate_per_minute}--;
			$data{rate_per_minute} = ($data{rate_per_minute} < 0) ? 0 : $data{rate_per_minute};
			$data{rate_per_minute} = ($data{rate_per_minute} > 100) ? 100 : $data{rate_per_minute};
			$data{rate_max_call_seconds}++;
			$data{rate_max_call_seconds}--;
			$data{rate_max_call_seconds} = ($data{rate_max_call_seconds} < 0) ? 0 : $data{rate_max_call_seconds};
			$data{rate_max_call_seconds} = ($data{rate_max_call_seconds} > 43200) ? 43200 : $data{rate_max_call_seconds};
			# print debug
			#warning("get_rate: rate FOUND");
			#warning("id = $data{rate_id} ");
			#warning("prefix = $data{rate_prefix}");
			#warning("country = $data{rate_country} ");
			#warning("areacode = $data{rate_areacode} ");
			#warning("rate_per_call = $data{rate_per_call} ");
			#warning("rate_per_minute = $data{rate_per_minute} ");
			#warning("max_seconds = $data{rate_max_call_seconds}");
		} else {
			$data{rate_found}			= 0;
			$data{rate_number_prefix}	= "";
		}
    } else {
		# nao achou rate
		$data{rate_found}			= 0;
		$data{rate_number_prefix}	= "";
    }
    #
    # validate rate
    if ($data{rate_found} eq 1) {
		$data{ok_to_use} = 0;
		if ($data{asterisk_string_raw} ne ""){
			#
			# ediciona channel no inicio (nao ta bem seguro, mas ta aceitavel por agora)
			# rota de skype e sobreposta por SKYPE/number ... ignora o que vem do banco
			# se nao souber, permanece como sip
			$data{asterisk_string_raw_before} = $data{asterisk_string_raw};
			if ($data{number_type} eq "SKYPE") {
				$data{asterisk_string_raw} = (index($data{asterisk_string_raw},"/") eq -1) ? "SKYPE/$data{asterisk_string_raw}" : $data{asterisk_string_raw};
			} elsif ($data{number_type} eq "SIP") {	
				$data{asterisk_string_raw} = (index($data{asterisk_string_raw},"/") eq -1) ? "SIP/$data{asterisk_string_raw}" : $data{asterisk_string_raw};
			} else {
				$data{asterisk_string_raw} = (index($data{asterisk_string_raw},"/") eq -1) ? "SIP/$data{asterisk_string_raw}" : $data{asterisk_string_raw};
			}
			#
		    # calcule route
			$tmp = $data{asterisk_string_raw};
			$tmp1="<PREFIX>"; 	$tmp2=$data{rate_prefix}; 	$tmp =~ s/$tmp1/$tmp2/g;
			$tmp1="<COUNTRY>"; 	$tmp2=$data{rate_country}; 	$tmp =~ s/$tmp1/$tmp2/g;
			$tmp1="<AREACODE>"; $tmp2=$data{rate_areacode}; $tmp =~ s/$tmp1/$tmp2/g;
			$tmp1="<FULL>"; 	$tmp2=$data{number}; 		$tmp =~ s/$tmp1/$tmp2/g;
			$tmp1="<NUMBER>"; 	$tmp2=substr($data{number},length($data{rate_prefix}.$data{rate_country}.$data{rate_areacode}),100) ; 											$tmp =~ s/$tmp1/$tmp2/g;
			$tmp1="<E164>"; 	$tmp2=$data{rate_country}.$data{rate_areacode}.substr($data{number},length($data{rate_prefix}.$data{rate_country}.$data{rate_areacode}),100) ; 	$tmp =~ s/$tmp1/$tmp2/g;
			$data{asterisk_string} = $tmp;
			$data{ok_to_use} = 1;
		}
    }
	#
	# return
	return %data;
}
sub multilevel_call_get_rate(){
	local($number,$product_id,$table) = @_;
	local(%data,$sql,$sql_1,$sql_2,%hash,$i,$sub,$tmp,$tmp1,$tmp2,$tmp4);
	%data = ();
    $data{is_peak} 				= 0;
    $data{is_reduced} 			= 0;
    $data{number}				= $number;
    $data{product_id}			= $product_id;
    $data{rate_table}			= ("\L$table" eq "product_rate_callback") ? "product_rate_callback" : "product_rate";
    $data{rate_id}				= "";
    $data{rate_number_prefix}	= "";
	$data{rate_found}			= 0;
	$data{rate_prefix}			= "";
	$data{rate_country}			= "";
	$data{rate_areacode}		= "";
	$data{rate_name}			= "";
	$data{rate_resolution}		= 1;
	$data{rate_min_call_seconds}= 1;
	$data{rate_grace_seconds}	= 0;
	$data{rate_rate_per_call}	= 0;
	$data{rate_rate_per_minute}	= 0;
	$data{rate_max_call_seconds}= 0;
	$data{rate_rate_id}			= "";
    $data{number_length}		= length($data{number});
    #
    # verifica se estamos em peak ou reduced time
    %today = &get_today();
	#if (1 eq 0) {
	#    $sql_1 	= "rateswitch_peak_". $today{WEEK_DAY} ."_". substr("00".$today{HOUR},-2,2);
	#    $sql_2 	= "rateswitch_reduced_". $today{WEEK_DAY} ."_". substr("00".$today{HOUR},-2,2);
	#    $sql 	= "select 1,1,$sql_1,$sql_2 from product where id='$data{product_id}' ";
	#    %hash	= &database_select_as_hash($sql,"flag,is_peak,is_reduced");
	#}
    #$data{is_reduced}	= ( ($hash{1}{flag} eq 1) && ($hash{1}{is_reduced} eq 1) ) ? 1 :  0;
    #$data{is_peak}   	= ( ($hash{1}{flag} eq 1) && ($hash{1}{is_peak}    eq 1) ) ? 1 :  0;
    #$data{is_reduced}	= ($data{is_peak} eq 1) ? 0 : $data{is_reduced};
    $data{is_reduced}	= 0;
    $data{is_peak}   	= 0;
    #
    # busca tarifa pra esse destination
    $sql = "SELECT 1,1,max(length(concat(prefix,country,areacode))) FROM $data{rate_table} where product_id = '$data{product_id}' ";
    %hash = &database_select_as_hash($sql,"flag,len");
    if ($hash{1}{flag} eq 1) { $data{number_length} = ($data{number_length} > $hash{1}{len}) ? $hash{1}{len} : $data{number_length}; }
    if ($data{number_length}>0) {
		foreach $i (1..$data{number_length}) {
			$sub = substr($data{number},0,$i);
			$sql = "SELECT 1,1,id FROM $data{rate_table} where product_id = '$data{product_id}' and concat(prefix,country,areacode) = '$sub' LIMIT 0,1";
			%hash = &database_select_as_hash($sql,"flag,id");
			if ($hash{1}{flag} eq 1) {$data{rate_id} = $hash{1}{id}; $data{rate_number_prefix}=$sub;}
		}
    }
	#
	# verificas numeros bloqueados
	$dst_block = "|16192127761|12153999293|16464344612|16464344613|16464344614|16464344615|16464344616|16464344617|16464344618|16464344619|16464344620|16464344621|16464344622|16464344623|16464344624|16464344625|16464344626|16464344627|16464344628|16464344629|16464344630|16464344631|16785376576|14108649137|16175351939|12162580292|13123486016|16142953007|12144160101|13137430146|17134015184|12014032079|17025833342|12135310063|13059086090|16154722025|17182909990|18474009651|12153999293|16022811146|16136759194|12027300310|8662575604|6464344632|6468736314|6468736324|6468736341|6468736342|6468736374|6468736394|6468736913|6468736914|6468736927|6468736928|6468736929|6468736934|";
	if ( index($dst_block ,"|$data{number}|") ne-1){
		$data{rate_id} = "";
		$data{rate_number_prefix} = "";
		$data{rate_dst_block} = 1;
	}
	#
	# se achou, vamos agir
    if ($data{rate_id} ne "") {
		$tmp1 = 							"rate_per_call,rate_per_minute,max_call_seconds";
		$tmp1 = ($data{is_peak} eq 1) ? 	"rate_per_call_peak,rate_per_minute_peak,max_call_seconds_peak" : $tmp1;
		$tmp1 = ($data{is_reduced} eq 1) ?	"rate_per_call_reduced,rate_per_minute_reduced,max_call_seconds_reduced" : $tmp1;
		$sql = "SELECT 1,1,prefix,country,areacode,name,resolution,min_call_seconds,grace_seconds,$tmp1 FROM $data{rate_table} where id = '$data{rate_id}' ";
		%hash = &database_select_as_hash($sql,"flag,prefix,country,areacode,name,resolution,min_call_seconds,grace_seconds,rate_per_call,rate_per_minute,max_call_seconds");
		if ($hash{1}{rate_per_minute} ne 100) {
			$data{rate_found}			= 1;
			$data{rate_prefix}			= $hash{1}{prefix};
			$data{rate_country}			= $hash{1}{country};
			$data{rate_areacode}		= $hash{1}{areacode};
			$data{rate_name}			= $hash{1}{name};
			$data{rate_resolution}		= $hash{1}{resolution};
			$data{rate_min_call_seconds}= $hash{1}{min_call_seconds};
			$data{rate_grace_seconds}	= $hash{1}{grace_seconds};
			$data{rate_per_call}		= $hash{1}{rate_per_call};
			$data{rate_per_minute}		= $hash{1}{rate_per_minute};
			$data{rate_max_call_seconds}= $hash{1}{max_call_seconds};
			# limpa e confere os valores
			$data{rate_resolution}++;
			$data{rate_resolution}--;
			$data{rate_resolution} = ($data{rate_resolution} < 1) ? 1 : $data{rate_resolution};
			$data{rate_resolution} = ($data{rate_resolution} > 43200) ? 43200 : $data{rate_resolution};
			$data{rate_min_call_seconds}++;
			$data{rate_min_call_seconds}--;
			$data{rate_min_call_seconds} = ($data{rate_min_call_seconds} < 0) ? 0 : $data{rate_min_call_seconds};
			$data{rate_min_call_seconds} = ($data{rate_min_call_seconds} > 43200) ? 43200 : $data{rate_min_call_seconds};
			$data{rate_grace_seconds}++;
			$data{rate_grace_seconds}--;
			$data{rate_grace_seconds} = ($data{rate_grace_seconds} < 0) ? 0 : $data{rate_grace_seconds};
			$data{rate_grace_seconds} = ($data{rate_grace_seconds} > 43200) ? 43200 : $data{rate_grace_seconds};
			$data{rate_per_call}++;
			$data{rate_per_call}--;
			$data{rate_per_call} = ($data{rate_per_call} < 0) ? 0 : $data{rate_per_call};
			$data{rate_per_call} = ($data{rate_per_call} > 100) ? 100 : $data{rate_per_call};
			$data{rate_per_minute}++;
			$data{rate_per_minute}--;
			$data{rate_per_minute} = ($data{rate_per_minute} < 0) ? 0 : $data{rate_per_minute};
			$data{rate_per_minute} = ($data{rate_per_minute} > 100) ? 100 : $data{rate_per_minute};
			$data{rate_max_call_seconds}++;
			$data{rate_max_call_seconds}--;
			$data{rate_max_call_seconds} = ($data{rate_max_call_seconds} < 0) ? 0 : $data{rate_max_call_seconds};
			$data{rate_max_call_seconds} = ($data{rate_max_call_seconds} > 43200) ? 43200 : $data{rate_max_call_seconds};
			# print debug
			#&asterisk_debug_print("$debug_app_name get_rate: rate FOUND");
			#&asterisk_debug_print("$debug_app_name           id = $data{rate_id} ");
			#&asterisk_debug_print("$debug_app_name           prefix = $data{rate_prefix}");
			#&asterisk_debug_print("$debug_app_name           country = $data{rate_country} ");
			#&asterisk_debug_print("$debug_app_name           areacode = $data{rate_areacode} ");
			#&asterisk_debug_print("$debug_app_name           rate_per_call = $data{rate_per_call} ");
			#&asterisk_debug_print("$debug_app_name           rate_per_minute = $data{rate_per_minute} ");
			#&asterisk_debug_print("$debug_app_name           max_seconds = $data{rate_max_call_seconds}");
		} else {
			$data{rate_found}			= 0;
			$data{rate_number_prefix}	= "";
		}
    } else {
		#
		# nao achou rate
		$data{rate_found}			= 0;
		$data{rate_number_prefix}	= "";
    }
	#
	# return
	return %data;
}
#
#------------------------
# coupons
#------------------------
sub multilevel_coupon_assign(){
	#
	# start
	local (%coupon) = @_;
	local (%data,%hash,$tmp,$tmp1,$tmp2,$sql);
	$coupon{message} = "";
	$coupon{ok}	= 0;
	$coupon{debug} .= "START: now debug belong to multilevel_coupon_assign function ! ";
	#
	# confere service id
	$coupon{service_id} = clean_int($coupon{service_id});
	if ($coupon{service_id} eq "") {
		$coupon{message} = "001";
		return %coupon;
	}
	#
	# confere coupon_type_id
	$coupon{coupon_type_id} = clean_int($coupon{coupon_type_id});
	if ($coupon{coupon_type_id} eq "") {
		$coupon{message} = "002";
		return %coupon;
	}
	#
	# verifica quantos tem free
	$sql = "
	SELECT 1,1,count(*)
	FROM
	service_coupon_stock,service_coupon_stock_status
	where
	service_coupon_stock.coupon_type_id='$coupon{coupon_type_id}' and
	service_coupon_stock.status=service_coupon_stock_status.id and
	service_coupon_stock_status.is_ready_to_assign=1
	";
	%hash = database_select_as_hash($sql,"flag,value");
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{value}>=1) ) {
		$coupon{message} = "011";
		return %coupon;
	}
	$coupon{coupons_available} = $hash{1}{value};
	#
	# busca um coupon livre e tenta assign
	# prepara pra errar
	$coupon{message} = "020";
	foreach (1..3) {
		# eu sorteio qual coupon pra evitar sobreposicao de pedidos de assign
		$tmp1 = int(rand(($coupon{coupons_available}-1)));
		$sql = "
		SELECT 1,1,service_coupon_stock.id
		FROM
		service_coupon_stock,service_coupon_stock_status
		where
		service_coupon_stock.coupon_type_id='$coupon{coupon_type_id}' and
		service_coupon_stock.status=service_coupon_stock_status.id and
		service_coupon_stock_status.is_ready_to_assign=1 and
		service_coupon_stock.service_id is null
		limit $tmp1,1
		";
		%hash = database_select_as_hash($sql,"flag,value");
		if ( ($hash{1}{flag} eq 1) && ($hash{1}{value}>=1) ) {
			# achei um coupon livre... vamos assign
			$coupon{coupon_stock_id} = $hash{1}{value};
			# TODO: status tem que ser uma variavel dinamica vindo do banco e nao hardcoded
			$sql = "
			update service_coupon_stock
			set status='2', slice_timestamp=now(), service_id='$coupon{service_id}', cc_fingerprint='$coupon{cc_fingerprint}'
			where id='$coupon{coupon_stock_id}'
			";
			database_do($sql);
			$coupon{message} = "000";
			$coupon{ok}	= 1;
			&action_history("coupon:status:assign",('coupon_stock_id'=>$coupon{coupon_stock_id},'service_id'=>$coupon{service_id}));
			last;
		}
	}
	#
	# return
	return %coupon;
}
sub multilevel_coupon_next_slice(){
	#
	##### start
	local ($coupon_stock_id) = @_;
	local (%coupon,%slices,%slice,%order,%hash,$tmp,$tmp1,$tmp2,$sql);
	#
	##### confere coupon existe
	$sql = "
	select 1,1,
		service_coupon_stock.id,
		service_coupon_stock.service_id,
		service_coupon_type.auto_pause_engine
	from
		service_coupon_stock,service_coupon_type
	where
		service_coupon_stock.id ='$coupon_stock_id' and
		service_coupon_stock.coupon_type_id = service_coupon_type.id
	";
	%hash = database_select_as_hash($sql,"flag,id,service_id,auto_pause_engine");
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $coupon_stock_id) && ($hash{1}{id} ne "") ) {return -1;}
	#
	##### check auto recharge engine
	if ($hash{1}{auto_pause_engine} eq "autorecharge") {
        &multilevel_coupon_engine_autorecharge($hash{1}{service_id});
	}
	#
	##### pega dados do coupon
	$sql = "
	select 1,1,
		service_coupon_stock.id,
		service_coupon_stock.service_id,
		service_coupon_stock.slice_index,
		unix_timestamp(service_coupon_stock.slice_timestamp),
		service_coupon_stock_status.is_ready_to_next_slice,
		service_status.coupon_pause_all
	from
		service_coupon_stock,
		service_coupon_stock_status,
		service,
		service_status
	where
		service_coupon_stock.id ='$coupon_stock_id' and
		service_coupon_stock.service_id is not null and
		service_coupon_stock.status=service_coupon_stock_status.id and
		service_coupon_stock.service_id = service.id and
		service.status = service_status.id and
		service_status.deleted = 0 and
		service_coupon_stock_status.is_in_use = 1
	";
	%hash = database_select_as_hash($sql,"flag,coupon_stock_id,service_id,slice_index,slice_timestamp,is_ready_to_next_slice,pause_by_status");
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{coupon_stock_id}>=$coupon_stock_id) ) {
		return -1;
	}
	%coupon = %{$hash{1}};
	$coupon{slice_index} = ($coupon{slice_index} eq "") ? 0 : $coupon{slice_index};
	$coupon{next_slice_index} = $coupon{slice_index}+1;
	#
	# se ta paused, update timestamp e retorna
	if ( ($coupon{is_ready_to_next_slice} ne 1) || ($coupon{pause_by_status} eq 1) ) {
		&database_do("update service_coupon_stock set slice_timestamp=now() where id ='$coupon_stock_id' ");
		return 2;
	}
	#
	# daqui pra baixo ta active, temos que ver a proxima slice
	#
	# pega a lista de slices
	$sql = "
	select
		service_coupon_type_slice.sequence,
		service_coupon_type_slice.title,
		service_coupon_type_slice.type,
		service_coupon_type_slice.delay_in_hours,
		service_coupon_type_slice.value
	from
		service_coupon_stock,
		service_coupon_type,
		service_coupon_type_slice
	where
		service_coupon_stock.id ='$coupon_stock_id' and
		service_coupon_stock.coupon_type_id = service_coupon_type.id and
		service_coupon_stock.coupon_type_id = service_coupon_type_slice.coupon_type_id
	";
	%slices = database_select_as_hash($sql,"title,type,hour,value");
	#
	# se next slice nao existe, finalizar
	unless (exists($slices{$coupon{next_slice_index}})) {
		&multilevel_coupon_finish($coupon_stock_id);
		return -2;
	}
	%slice = %{$slices{$coupon{next_slice_index}}};
	#
	# verifica se ja deu timeout pra aplicar
	if ( (time-$coupon{slice_timestamp}) < ($slice{hour}*60*60) ) {
		#print time."-$coupon{slice_timestamp}=".(time-$coupon{slice_timestamp})."  < $slice{hour} (".($slice{hour}*60).")\n";
		return 3;
	}
	#
	# aplica a slice
	%order = ();
	$order{service_id}			= $coupon{service_id};
	$order{value_credit}		= $slice{value};
	$order{value_money}			= 0;
	$order{type}				= "FREE";
	$order{text}				= $slice{title};
	$order{source_type}			= "COUPON";
	$order{coupon_stock_id}		= $coupon_stock_id;
	$order{coupon_slice_index}	= $coupon{next_slice_index};
	$order{ok}					= 0;
	%order = multilevel_credit_add(%order);
	#print "DEBUG=$order{debug}\n";
	if ($order{ok} eq 1)  {
		&action_history("coupon:slice:free",('coupon_stock_id'=>$coupon_stock_id,'service_id'=>$coupon{service_id},'credit_id'=>$order{new_credit_id}));
	} else {
		&action_history("coupon:slice:error",('coupon_stock_id'=>$coupon_stock_id,'service_id'=>$coupon{service_id}));
		if (&multilevel_coupon_stop($coupon_stock_id) eq 1) {
			&action_history("coupon:status:stopbyerror",('coupon_stock_id'=>$coupon_stock_id,'service_id'=>$coupon{service_id}));
		}
		return -3
	}
	#
	# fecha se terminou
	$tmp = $coupon{next_slice_index}+1;
	unless (exists($slices{$tmp})) {
		&multilevel_coupon_finish($coupon_stock_id);
		return 4;
	}
	#
	# prepara pra proxima ou
	&database_do("update service_coupon_stock set slice_index='$coupon{next_slice_index}', slice_timestamp=now() where id ='$coupon_stock_id' ");
	return 1;

}
sub multilevel_coupon_pause(){
	local ($id) = @_;
	local (%hash,$tmp,$tmp1,$tmp2,$sql);
	%hash = database_select_as_hash("SELECT 1,1,status,service_id from service_coupon_stock where id='$id' ","flag,value,service_id");
	if ( ($hash{1}{flag} eq 1) && ($hash{1}{value} eq 2) ) {
		&database_do("update service_coupon_stock set status='3' where id ='$id' ");
		return 1;
	} else {
		return 0;
	}
}
sub multilevel_coupon_unpause(){
	local ($id) = @_;
	local (%hash,$tmp,$tmp1,$tmp2,$sql);
	%hash = database_select_as_hash("SELECT 1,1,status,service_id from service_coupon_stock where id='$id' ","flag,value,service_id");
	if ( ($hash{1}{flag} eq 1) && ($hash{1}{value} eq 3) ) {
		&database_do("update service_coupon_stock set status='2',slice_timestamp=now() where id ='$id' ");
		return 1;
	} else {
		return 0;
	}
}
sub multilevel_coupon_stop(){
	local ($id) = @_;
	local (%hash,$tmp,$tmp1,$tmp2,$sql);
	%hash = database_select_as_hash("SELECT 1,1,status,service_id from service_coupon_stock where id='$id' ","flag,value,service_id");
	if ( ($hash{1}{flag} eq 1) && ( ($hash{1}{value} eq 3) || ($hash{1}{value} eq 2)) ) {
		&database_do("update service_coupon_stock set status='4' where id ='$id' ");
		return 1;
	} else {
		return 0;
	}
}
sub multilevel_coupon_unstop(){
	local ($id) = @_;
	local (%hash,$tmp,$tmp1,$tmp2,$sql);
	%hash = database_select_as_hash("SELECT 1,1,status,service_id from service_coupon_stock where id='$id' ","flag,value,service_id");
	if ( ($hash{1}{flag} eq 1) && ($hash{1}{value} eq 4) ) {
		#TODO: reverificar se deve ir pra pause ou active. criar rotina separada pra isso
		&database_do("update service_coupon_stock set status='3' where id ='$id' ");
		&multilevel_coupon_engine_autorecharge($hash{1}{service_id});
		return 1;
	} else {
		return 0;
	}
}
sub multilevel_coupon_finish(){
	local ($id) = @_;
	local (%coupon,%slices,%slice,%order,%hash,$tmp,$tmp1,$tmp2,$sql);
	%hash = database_select_as_hash("SELECT 1,1,service_id from service_coupon_stock where id='$id' ","flag,value");
	if ( ($hash{1}{flag} eq 1) ) {
		&database_do("update service_coupon_stock set status='5' where id ='$id' ");
		&action_history("coupon:status:finish",('coupon_stock_id'=>$id,'service_id'=>$hash{1}{value}));
		return 1;
	}
	return 0;
}
sub multilevel_coupon_engine_autorecharge_can_assign(){
	# was autorecharge_coupon_can_assign
	local($service_id) =@_;
	local($sql,%hash,$msg);
	$sql = "
		select 1,1,service_coupon_type.ui_msg_out_stock
		from service,service_status,service_coupon_type
		where
		service.id='$service_id'
		and service.status=service_status.id
		and service_status.coupon_id_auto_recharge_signin = service_coupon_type.id
		and service_coupon_type.auto_pause_engine='autorecharge'
		and service_status.can_auto_recharge = 1
	";
	%hash = database_select_as_hash($sql,"flag,msg");
	if ($hash{1}{flag} ne 1) { return 0 }
	$sql = "
		select 1,1,count(*)
		from service_coupon_type,service_coupon_stock
		where
		service_coupon_stock.service_id='$service_id'
		and service_coupon_type.auto_pause_engine='autorecharge'
		and service_coupon_stock.coupon_type_id=service_coupon_type.id
	";
	%hash = database_select_as_hash($sql,"flag,qtd");
	if ($hash{1}{flag} ne 1) { return 0 }
	if ($hash{1}{qtd} ne 0) { return 0 }
	return 1;
}
sub multilevel_coupon_engine_autorecharge{
	local($service_id) = @_;
	local(%hash,%hash1,%hash2,$coupon_stock_id,$coupon_pause );
	# check service_id
	$sql = "select 1,1 from service where id='$service_id'";
	%hash = database_select_as_hash($sql,"flag");
	if ($hash{1}{flag} ne 1) { return 0 }
	# get auto recharge e cc profile
	%hash1 = &multilevel_securedata_cc_get($service_id);
	%hash2 = &database_select_as_hash("SELECT 1,1,cc_fingerprint FROM service_profile_cc where service_id='$service_id' and active=1 and is_auto_recharge=1 ","flag,cc_fingerprint");
	# get coupons to act
	$sql = "
	select
		service_coupon_stock.id,service_coupon_stock.cc_fingerprint
	from
		service,
		service_coupon_type,
		service_coupon_stock,
		service_coupon_stock_status
	where
		service.id='$service_id'
		and service.id = service_coupon_stock.service_id
		and service_coupon_stock.coupon_type_id = service_coupon_type.id
		and service_coupon_stock.status = service_coupon_stock_status.id
		and service_coupon_type.auto_pause_engine='autorecharge'
		and service_coupon_stock_status.is_finished<>1
	";
	%hash = &database_select_as_hash($sql,"cc_fingerprint");
	foreach $coupon_stock_id (keys %hash){
		$coupon_pause = 1;
		if ($hash1{status_ok} eq 1) {
			if ($hash2{1}{flag} eq 1) {
				if ($hash2{1}{cc_fingerprint} eq $hash{$coupon_stock_id}{cc_fingerprint}) {
					$coupon_pause = 0;
				}
			}
		}
		if ($coupon_pause eq 1) {
			if (&multilevel_coupon_pause($coupon_stock_id) eq 1){
				&action_history("coupon:status:pause",('coupon_stock_id'=>$coupon_stock_id,'service_id'=>$service_id));
			}
		} else {
			if (&multilevel_coupon_unpause($coupon_stock_id) eq 1){
				&action_history("coupon:status:unpause",('coupon_stock_id'=>$coupon_stock_id,'service_id'=>$service_id));
			}
		}
	}
	return 1;
}
#
#------------------------
# track ANI and validation
#------------------------
sub multilevel_anicheck_data_load(){
	local($service_id) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	#
	# start
	%data = ();
	#
	# limpa service_id
	$service_id = substr(&clean_int($service_id),0,200);
	if ($service_id eq "") {return %data}
	#
	# pega data no servico
	$buf = &data_get("service_data",$service_id,"anicheck_1");
	$buf .= &data_get("service_data",$service_id,"anicheck_2");
	#
	# monta o hash
	$pointer = 1;
	foreach $tmp (split(/\,/,$buf)){
		if ($tmp eq "") {next}
		if (substr($tmp,-1,1) ne ".") {next}
		$tmp = substr($tmp,0,-1);
		$data{substr($tmp,1,100)}{i} = $pointer;
		$data{substr($tmp,1,100)}{f} = substr($tmp,0,1);
		$pointer++;
	}
	#
	# return
	return %data
}
sub multilevel_anicheck_data_save(){
	local($service_id,%data) = @_;
	local($buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	#
	# start
	$buf = "";
	#
	# limpa service_id
	$service_id = substr(&clean_int($service_id),0,200);
	if ($service_id eq "") {return %data}
	#
	# add flag=1 no buf
	foreach $tmp (sort{$data{$a}{i} <=> $data{$b}{i}} keys %data) {
		if ($data{$tmp}{f} ne 1) {next}
		$buf .= "1$tmp.,";
	}
	#
	# add flag=0 no buf
	foreach $tmp (sort{$data{$a}{i} <=> $data{$b}{i}} keys %data) {
		if ($data{$tmp}{f} ne 0) {next}
		$buf .= "0$tmp.,";
	}
	#
	# pega data no servico
	&data_set("service_data",$service_id,"anicheck_1",substr($buf,0,200));
	if (length($buf)>=200){
		&data_set("service_data",$service_id,"anicheck_2",substr($buf,200,400));
	} else {
		&data_set("service_data",$service_id,"anicheck_2","");
	}
	#
	# return
	return 1;
}
sub multilevel_anicheck_set(){
	local($service_id,$ani) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	%data = &multilevel_anicheck_data_load($service_id);
	$data{$ani}{i}=0;
	$data{$ani}{f}=1;
	&multilevel_anicheck_data_save($service_id,%data);
}
sub multilevel_anicheck_unset(){
	local($service_id,$ani) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	%data = &multilevel_anicheck_data_load($service_id);
	## yes we allow unset even if number was not set before
	## imagine set as a extra layer of chocolat.. unset i ok, but set is more than ok : )
	##unless (exists($data{$ani})) {return}
	$data{$ani}{i}=0;
	$data{$ani}{f}=0;
	&multilevel_anicheck_data_save($service_id,%data);
}
sub multilevel_anicheck_touch(){
	local($service_id,$ani) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	%data = &multilevel_anicheck_data_load($service_id);
	if (exists($data{$ani})) {
		$data{$ani}{i}=0;
	} else {
		$data{$ani}{i}=0;
		$data{$ani}{f}=0;
	}
	&multilevel_anicheck_data_save($service_id,%data);
}
sub multilevel_anicheck_check(){
	local($service_id,$ani) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	%data = &multilevel_anicheck_data_load($service_id);
	if (exists($data{$ani})) {return 1} else {return 0}
}
sub multilevel_anicheck_delete(){
	local($service_id,$ani) = @_;
	local($data,$buf,$pointer);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	%data = &multilevel_anicheck_data_load($service_id);
	delete($data{$ani});
	&multilevel_anicheck_data_save($service_id,%data);
}
#
#------------------------
# authorie functions
#------------------------
sub multilevel_ss_check(){
	return 1;
	local($value) = @_;
	#use SSN::Validate;
	#my $ssn = SSN::Validate->new({'ignore_bad_combo' => 1});
	#return ($ssn->valid_ssn($value)) ? 1 : 0;
}
sub multilevel_securedata_clean_bad_links(){
	local($service_id,$cim_profile_id) = @_;
	local($MyData,$debug,$debug_id);
	if ($service_id ne "") {
		error("Remove CIM_id link from service=$service_id");
		&data_delete("service_data",$service_id,"CIM_ID");
	}
	if ($cim_profile_id ne "") {
		error("Remove profile=$cim_profile_id from CIM ");
		$MyData = &authorize_cim_transaction("deleteCustomerProfileRequest","<customerProfileId>$cim_profile_id</customerProfileId>");
	}
}
sub authorize_cim_transaction(){
	use LWP::UserAgent;
	use HTTP::Request;
	use HTTP::Headers;
	use XML::Simple;
	my($xml_header,$xml_data) = @_;
	my($xml_request,$objData,$objHeader,$objRequest,$objUserAgent,$objUserAgent,$objSimple,$answer);
	$app{authorize_api_login_id}		= &data_get("system_config","authorize","login_id");
	$app{authorize_api_tran_key}		= &data_get("system_config","authorize","tran_key");
	$app{authorize_api_is_test}			= &data_get("system_config","authorize","is_test");
	$objData = "";
	$objData->{STATUS_OK}=0;
	$objData->{STATUS_MESSAGE}="";
	$xml_request = qq[<?xml version="1.0" encoding="utf-8"?>
	<$xml_header xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
		<merchantAuthentication>
			<name>$app{authorize_api_login_id}</name>
			<transactionKey>$app{authorize_api_tran_key}</transactionKey>
		</merchantAuthentication>
		$xml_data
	</$xml_header>
	];
	$objHeader = HTTP::Headers->new;
	$objHeader->push_header('Content-Type' => 'text/xml');
	if ($app{authorize_api_is_test} eq 1) {
		$objRequest = HTTP::Request->new("POST","https://apitest.authorize.net/xml/v1/request.api",$objHeader,$xml_request);
	} else {
		$objRequest = HTTP::Request->new("POST","https://api.authorize.net/xml/v1/request.api",$objHeader,$xml_request);
	}
	$objUserAgent = LWP::UserAgent->new;
	$objResponse = $objUserAgent->request($objRequest);
	if (!$objResponse->is_error) {
		$objSimple 	= XML::Simple->new();
		$objData	= $objSimple->XMLin($objResponse->content);
		if ("\U$objData->{messages}->{resultCode}" eq "OK") {
			$objData->{STATUS_OK}=1;
			$objData->{STATUS_MESSAGE}=$objData->{messages}->{message}->{text};
		} else {
			$objData->{STATUS_OK}=0;
			$objData->{STATUS_MESSAGE}=$objData->{messages}->{message}->{text};
		}
	} else {
		$objData->{STATUS_OK}=0;
		$objData->{STATUS_MESSAGE}= "Network error: ".$objResponse->message;
	}
	return $objData;
}
sub multilevel_securedata_ss_set(){
	local($service_id,$value) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData,$debug,$debug_id,$tmp,$tmp1,$tmp2);
	#- verifica cim_profile_id
	$cim_profile_id = &data_get("service_data",$service_id,"CIM_ID");
	#- se nao tem vamos criar o profile#
	if ($cim_profile_id eq "") {
		#	- criar no CIM ja incluindo o SS
		$xml_data = qq[
		<profile>
			<merchantCustomerId>$service_id</merchantCustomerId>
			<description>$value</description>
		</profile>
		<validationMode>none</validationMode>
		];
		$MyData = &authorize_cim_transaction("createCustomerProfileRequest",$xml_data);
		#	- se teve erro, retornar 0
		if ($MyData->{STATUS_OK} eq 0) {
			if (index($MyData->{STATUS_MESSAGE},"duplicate record with id") ne -1) {
				#
				# se (A duplicate record with id), buscar a id antiga
				$MyData = &authorize_cim_transaction("getCustomerProfileIdsRequest","");
				@array = @{$MyData->{ids}->{numericString}};
				$tmp2 = 0;
				foreach $tmp1 (@array){
					$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$tmp1</customerProfileId>");
					if ($MyData->{profile}->{merchantCustomerId} eq $service_id) {
						$tmp2 = $tmp1;
						last;
					}
				}
				if ($tmp2 eq 0) {
					return 0;
				} else {
					&data_set("service_data",$service_id,"CIM_ID",$tmp2);
					$cim_profile_id = $tmp2;
				}
			} else {
				return 0;
			}
		} else {
			&data_set("service_data",$service_id,"CIM_ID",$MyData->{customerProfileId});
			$cim_profile_id = $MyData->{customerProfileId};
		}
		#	- pega o cim_profile_id e grava no servico
		&data_set("service_data",$service_id,"CIM_ID",$MyData->{customerProfileId});
		return 1;
	}
	#- OPCIONAL ler no CIM
	#- OPCIONAL se teve erro, retornar 0
	#- OPCIONAL se service id diferente, retorna 0 e chama multilevel_securedata_wipe_on_error
	#- update no CIM mandando o novo SS
	$xml_data = qq[
	<profile>
		<merchantCustomerId>$service_id</merchantCustomerId>
		<description>$value</description>
		<customerProfileId>$cim_profile_id</customerProfileId>
	</profile>
	];
	$MyData = &authorize_cim_transaction("updateCustomerProfileRequest",$xml_data);
	#- se teve erro, retornar 0
	if ($MyData->{STATUS_OK} eq 0) {
		#
		# sometimes we loose sync... data here but not in CIM,
		# let try to get this error and clean the shit
		if (index($MyData->{STATUS_MESSAGE},"The record cannot be found") ne -1){
			&multilevel_securedata_clean_bad_links($service_id,$cim_profile_id);
		}
		return 0;
	}
	#- retorna 1
	return 1;
}
sub multilevel_securedata_ss_get(){
	local($service_id,$value) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData);
	#- verifica cim_profile_id
	$cim_pofile_id = &data_get("service_data",$service_id,"CIM_ID");
	#- se nao tem retorna vazio
	if ($cim_pofile_id eq "") {return ""}
	#- ler no CIM
	$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$cim_pofile_id</customerProfileId>");
	#- se teve erro, retornar 0
	if ($MyData->{STATUS_OK} eq 0) {return ""}
	#- se service id diferente, retorna vazio e chama multilevel_securedata_wipe_on_error
	#- retorna SS number
	return $MyData->{profile}->{description};
}
sub multilevel_securedata_cc_del(){
	local($service_id) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData,$debug,$debug_id,$cim_payment_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	#
	#....................................
	# verifica service_id
	#....................................
	$service_id = clean_int($service_id);
	if ($service_id eq "") {
		info("breake by service_id=$service_id ");
		return 0;
	}
	$cim_profile_id = &data_get("service_data",$service_id,"CIM_ID");
	#
	#....................................
	# apaga table
	#....................................
	&database_do("update service_profile_cc set active=0 where service_id='$service_id' ");
	&multilevel_coupon_engine_autorecharge($service_id);
	return 1;
}
sub multilevel_securedata_cc_block_set(){
	#
	# in fact, we only need cc_fingerprint to block the card, but its better ask cc_profile that 
	# has the cc_fingerprint we want block because we can also know service_id to log
	# its not state-of-art but works in 99% :)
	#
	local($cc_profile_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%hash1,%hash2,%tmp_hash,%order,$sql);
	#
	# check cc_profile_id
	$sql = "SELECT 1,1,id,service_id,cc_fingerprint,active FROM service_profile_cc where id='$cc_profile_id'";
	%hash = database_select_as_hash($sql,"flag,id,service_id,cc_fingerprint,active");
    if ($hash{1}{flag} ne 1) { return 0 }
    #
    # add in block list
	$sql="delete from security_cc_block where cc_fingerprint='$hash{1}{cc_fingerprint}' "; &database_do($sql);
	$sql="insert into security_cc_block (cc_fingerprint,creation_date) values ('$hash{1}{cc_fingerprint}',now() )  "; &database_do($sql);
	#
	# flag error all active cc_profiles with this fingerprint
	$sql = "SELECT id,service_id FROM service_profile_cc where cc_fingerprint='$hash{1}{cc_fingerprint}' and active=1 ";
	%hash1 = database_select_as_hash($sql,"service_id");
	foreach $tmp1 (keys %hash1){
		$tmp2 = &multilevel_securedata_cc_error_set($tmp1);
	}
	#
	# log
	&action_history("cc:block:set",('service_id'=>$hash{1}{service_id}));
	# 
	# return
	return 1;
}
sub multilevel_securedata_cc_block_unset(){
	#
	# in fact, we only need cc_fingerprint to block the card, but its better ask cc_profile that 
	# has the cc_fingerprint we want block because we can also know service_id to log
	# its not state-of-art but works in 99% :)
	#
	local($cc_profile_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%hash1,%hash2,%tmp_hash,%order,$sql);
	#
	# check cc_profile_id
	$sql = "SELECT 1,1,id,service_id,cc_fingerprint,active FROM service_profile_cc where id='$cc_profile_id'";
	%hash = database_select_as_hash($sql,"flag,id,service_id,cc_fingerprint,active");
    if ($hash{1}{flag} ne 1) { return 0 }
    #
    # remove from block list
	&database_do("delete from security_cc_block where cc_fingerprint='$hash{1}{cc_fingerprint}' ");
	#
	# unflag error all active cc_profiles with this fingerprint (this is not 100% true, because maybe cc_profile has real error, but, as above... works in 99% of time)
	$sql = "SELECT id,service_id FROM service_profile_cc where cc_fingerprint='$hash{1}{cc_fingerprint}' and active=1 ";
	%hash1 = database_select_as_hash($sql,"service_id");
	foreach $tmp1 (keys %hash1){
		multilevel_securedata_cc_error_unset($tmp1);
	}
	#
	# log
	&action_history("cc:block:unset",('service_id'=>$hash{1}{service_id}));
	# 
	# return
	return 1;
}
sub multilevel_securedata_cc_block_is_fingerprint_blocked(){
	#
	# in fact, we only need cc_fingerprint to block the card, but its better ask cc_profile that 
	# has the cc_fingerprint we want block because we can also know service_id to log
	# its not state-of-art but works in 99% :)
	#
	local($fingerprint) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%hash1,%hash2,%tmp_hash,%order,$sql);
	#
	# flag error all active cc_profiles with this fingerprint
	$sql = database_scape_sql("SELECT 1,1,count(*) FROM security_cc_block where cc_fingerprint='%s' ",$fingerprint);
	%hash = database_select_as_hash($sql,"flag,value");
	if ( ($hash{1}{flag} eq 1) && ($hash{1}{value} eq 0) ){
		return 0;
	} else {
		return 1;
	}
}
sub multilevel_securedata_cc_error_set(){
	local($cc_profile_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,%order,$sql);
	#
	# check cc_profile_id
	$sql = "SELECT 1,1,id,service_id,cc_fingerprint,active FROM service_profile_cc where id='$cc_profile_id' and active=1 ";
	%hash = database_select_as_hash($sql,"flag,id,service_id,cc_fingerprint,active");
    if ($hash{1}{flag} ne 1) { return 0 }
    #
    # set error
	&data_delete("service_data",$hash{1}{service_id},"CIM_ERRORS");
	&database_do("update service_profile_cc set cc_error=1 where id='$cc_profile_id' ");
	#
	# do coupon check
	&multilevel_coupon_engine_autorecharge($hash{1}{service_id});
	#
	# log
	&action_history("cim:error:set",('service_id'=>$hash{1}{service_id}));
	# 
	# return
	return 1;
}
sub multilevel_securedata_cc_error_unset(){
	local($cc_profile_id) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,%order,$sql);
	#
	# check cc_profile_id
	$sql = "SELECT 1,1,id,service_id,cc_fingerprint,active FROM service_profile_cc where id='$cc_profile_id' and active=1 ";
	%hash = database_select_as_hash($sql,"flag,id,service_id,cc_fingerprint,active");
    if ($hash{1}{flag} ne 1) { return 0 }
    #
    # set error
	&data_delete("service_data",$hash{1}{service_id},"CIM_ERRORS");
	&database_do("update service_profile_cc set cc_error=0 where id='$cc_profile_id' ");
	#
	# do coupon check
	&multilevel_coupon_engine_autorecharge($hash{1}{service_id});
	#
	# log
	&action_history("cim:error:unset",('service_id'=>$hash{1}{service_id}));
	# 
	# return
	return 1;
}
sub multilevel_securedata_cc_set(){
	local(%order) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$service_id,$xml_data,$MyData,$debug,$debug_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash);
	#use Data::Dumper;
	$order{status_ok} 		= 0;
	$order{status_code} 	= 0;
	$order{status_message}	= "Unknown";
	#
	#....................................
	# verifica service_id
	#....................................
	$service_id = clean_int($order{service_id});
	if ($service_id eq "") {
		$order{status_code} 	= 1;
		$order{status_message}	= "No service_id";
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		return %order;
	}
	#
	#....................................
	# confere coisas basicas
	#....................................
	$tmp = 0;
	if (&form_check_string($order{cc_type}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{cc_number}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{cc_date}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{cc_code}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{first_name})		ne 1) {$tmp++;}
	if (&form_check_string($order{last_name})		ne 1) {$tmp++;}
	if (&form_check_string($order{address}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{country}) 		ne 1) {$tmp++;}
	if (&form_check_string($order{city}) 			ne 1) {$tmp++;}
	if (&form_check_string($order{state}) 			ne 1) {$tmp++;}
	if (&form_check_string($order{zip}) 			ne 1) {$tmp++;}
	if (&form_check_string($order{contact_number}) 	ne 1) {$tmp++;}
	if ($tmp ne 0) {
		$order{status_code} 	= 2;
		$order{status_message}	= "Bad order data";
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		return %order;
	}
	$order{cc_date_full_year} = (substr($order{cc_date},2,2)+2000)."-".substr($order{cc_date},0,2);
	#
	#....................................
	# check is_fingerprint_blocked (DISABLED! now we check this at user interface at cc profile)
	#....................................
	$order{card_fingerprint} = key_md5("CC|$order{cc_number}|$order{cc_date}");
	$order{card_is_blocked} = &multilevel_securedata_cc_block_is_fingerprint_blocked($order{card_fingerprint});
	if ($order{card_is_blocked} eq 1) {
		$order{status_code} 	= 22;
		$order{status_message}	= "Card blocked";
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		&action_history("suspicious:addblockcard",('value_old'=>$order{card_fingerprint},'service_id'=>$order{service_id}));
		return %order;
	}
	#
	#....................................
	# verifica cim_profile_id
	#....................................
	$cim_profile_id = &data_get("service_data",$service_id,"CIM_ID");
	if ($cim_profile_id eq "") {
		#
		#....................................
		# se nao tem link, vamos procurar o profile
		#....................................
	}
	if ($cim_profile_id eq "") {
		#
		#....................................
		# se nao tem vamos criar o profile
		#....................................
		$order{debug} .= "no CIM profile, lets find/create ! ";
		$xml_data = qq[
		<profile>
			<merchantCustomerId>$service_id</merchantCustomerId>
			<description>$value</description>
		</profile>
		<validationMode>none</validationMode>
		];
		$MyData = &authorize_cim_transaction("createCustomerProfileRequest",$xml_data);
		$order{debug} .= "status=$MyData->{STATUS_OK} - $MyData->{STATUS_MESSAGE} ! ";
		if ($MyData->{STATUS_OK} eq 0) {
			if (index($MyData->{STATUS_MESSAGE},"duplicate record with id") ne -1) {
				#
				# se (A duplicate record with id), buscar a id antiga
				$order{debug} .= "Duplicate found! ! ";
				$order{debug} .= "delete recent $MyData->{customerProfileId} ! ";
				&multilevel_securedata_clean_bad_links($MyData->{customerProfileId});
				$order{debug} .= "lets search ! ";
				$MyData = &authorize_cim_transaction("getCustomerProfileIdsRequest","");
				@array = @{$MyData->{ids}->{numericString}};
				$tmp2 = 0;
				foreach $tmp1 (@array){
					$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$tmp1</customerProfileId>");
					$order{debug} .= "search $tmp1 - $MyData->{profile}->{merchantCustomerId} ! ";
					if ($MyData->{profile}->{merchantCustomerId} eq $service_id) {
						$tmp2 = $tmp1;
						last;
					}
				}
				if ($tmp2 eq 0) {
					#
					# se outro erro, aborta
					$order{status_code} 	= 3;
					$order{status_message}	= "I cannot create or find CIM profile for service_id=$service_id";
					&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
					return %order;
				} else {
					&data_set("service_data",$service_id,"CIM_ID",$tmp2);
					$cim_profile_id = $tmp2;
					$order{debug} .= "found $tmp2 ! ";
				}
			} else {
				#
				# se outro erro, aborta
				$order{status_code} 	= 4;
				$order{status_message}	= "I cannot create CIM profile for service_id=$service_id - $MyData->{STATUS_MESSAGE};";
				&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
				return %order;
			}
		} else {
			&data_set("service_data",$service_id,"CIM_ID",$MyData->{customerProfileId});
			$cim_profile_id = $MyData->{customerProfileId};
		}
	}
	#
	#....................................
	#- ler CIM profile
	#....................................
	$order{debug} .= "read CIM profile id=$cim_profile_id ! ";
	$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$cim_profile_id</customerProfileId>");
	$order{customerPaymentProfileId} = $MyData->{profile}->{paymentProfiles}->{customerPaymentProfileId};
	$order{debug} .= "status=$MyData->{STATUS_OK} - $MyData->{STATUS_MESSAGE} ! ";
	#$order{debug} .= "DUMP<br><pre>$xml_data\n".Dumper($MyData)."</pre><br>";
	$order{customerProfileId} = $cim_profile_id;
	#
	#....................................
	#- se teve erro leitura, retornar
	#....................................
	if ($MyData->{STATUS_OK} eq 0) {
		$order{status_code} 	= 5;
		$order{status_message}	= "I cannot read CIM profile_id=$cim_profile_id for service_id=$service_id - $MyData->{STATUS_MESSAGE};";
		if (index($MyData->{STATUS_MESSAGE},"The record cannot be found") ne -1){
			$order{debug} .= "delete link with cim_id=$cim_profile_id ! ";
			&multilevel_securedata_clean_bad_links($service_id,$cim_profile_id);
		}
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		return %order;
	}
	#
	#....................................
	#- se service id diferente, chama multilevel_securedata_wipe_on_error e retorna
	#....................................
	if ($MyData->{profile}->{merchantCustomerId} ne $service_id) {
		$order{debug} .= "incorrect service_id=".$MyData->{profile}->{merchantCustomerId}."=".$service_id." in cim_id=$cim_profile_id ! ";
		&multilevel_securedata_clean_bad_links($service_id,$cim_profile_id);
		$order{status_code} 	= 6;
		$order{status_message}	= "CIM with incorrect service_id";
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		return %order;
	}
	#
	#....................................
	#- de agora em diante, couro come, nao tem mais erro
	#....................................
	#
	#....................................
	#- apaga ALL CC no CIM
	#....................................
	$order{debug} .= "Delete payment profile ! ";
	if ($order{customerPaymentProfileId} ne "") {
		foreach(1..10){
			$order{debug} .= "try delete payment_id=$order{customerPaymentProfileId} ! ";
			$xml_data = qq[
			<customerProfileId>$cim_profile_id</customerProfileId>
			<customerPaymentProfileId>$order{customerPaymentProfileId}</customerPaymentProfileId>
			];
			$MyData = &authorize_cim_transaction("deleteCustomerPaymentProfileRequest",$xml_data);
			$order{debug} .= "status=$MyData->{STATUS_OK} - $MyData->{STATUS_MESSAGE} ! ";
			if ($MyData->{STATUS_OK} eq 1) {
				$order{debug} .= "delete ok ! ";
			} else {
				$order{debug} .= "no delete! something weirdo! lets abort ! ";
				last;
			}
			$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$cim_profile_id</customerProfileId>");
			$order{customerPaymentProfileId} = $MyData->{profile}->{paymentProfiles}->{customerPaymentProfileId};
			$order{debug} .= "next payment_id=$order{customerPaymentProfileId} ! ";
			if ($order{customerPaymentProfileId} eq "") {
				$order{debug} .= "no more payment_id to delete ! ";
				last;
			}
		}
	}
	#
	#....................................
	#- insere novo CC no CIM
	#....................................
	$tmp = (&data_get("system_config","authorize","is_test") eq 1) ? "none" : "liveMode";
	$xml_data = qq[
	<customerProfileId>$cim_profile_id</customerProfileId>
	<paymentProfile>
		<billTo>
			<firstName>$order{first_name}</firstName>
			<lastName>$order{last_name}</lastName>
			<company></company>
			<address>$order{address}</address>
			<city>$order{city}</city>
			<state>$order{state}</state>
			<zip>$order{zip}</zip>
			<country>$order{country}</country>
			<phoneNumber>$order{contact_number}</phoneNumber>
			<faxNumber></faxNumber>
		</billTo>
		<payment>
			<creditCard>
				<cardNumber>$order{cc_number}</cardNumber>
				<expirationDate>$order{cc_date_full_year}</expirationDate>
			</creditCard>
		</payment>
	</paymentProfile>
	<validationMode>$tmp</validationMode>
	];
	####<validationMode>none</validationMode>
	####<validationMode>testMode</validationMode>
	####<validationMode>liveMode</validationMode>
	$MyData = &authorize_cim_transaction("createCustomerPaymentProfileRequest",$xml_data);
	$order{debug} .= "create payment profile ! ";
	$order{debug} .= "status=$MyData->{STATUS_OK} - $MyData->{STATUS_MESSAGE} ! ";
	#$order{debug} .= "DUMP<br><pre>$xml_data\n".Dumper($MyData)."</pre><br>";
	if ($MyData->{STATUS_OK} eq 0) {
		$order{status_code} 	= 7;
		$order{status_message}	= "I cannot create CIM payment profile for service_id=$service_id - $MyData->{STATUS_MESSAGE};";
		&log_debug_add("type=securedata_cc_set,error=$order{status_code},service_id=$service_id",%order);
		return %order;
	}
	#
	# update db
	$order{customerPaymentProfileId} 	= $MyData->{customerPaymentProfileId};
	$order{card_fingerprint} 			= key_md5("CC|$order{cc_number}|$order{cc_date}");
	$order{cc_number_db}				= "************".substr($order{cc_number},-4,4);
	$sql = "
	insert into service_profile_cc
	(creation_date, active,  CIM_customerProfileId,        CIM_customerPaymentProfileId,         service_id,     ani,                       cc_type,            cc_fingerprint,              cc_number,               cc_date,            cc_code,            first_name,            last_name,            address,            country,            city,            state,            zip           ) values
	(now(),         1,       '$order{customerProfileId}',  '$order{customerPaymentProfileId}',   '$service_id',  '$order{contact_number}',  '$order{cc_type}',  '$order{card_fingerprint}',  '$order{cc_number_db}',  '$order{cc_date}',  '$order{cc_code}',  '$order{first_name}',  '$order{last_name}',  '$order{address}',  '$order{country}',  '$order{city}',  '$order{state}',  '$order{zip}' )
	";
	$order{debug} .= "update db ! $sql ! ";
	&database_do("update service_profile_cc set active=0 where service_id='$service_id' ");
	&database_do($sql);
	&multilevel_coupon_engine_autorecharge($service_id);
	#
	#....................................
	#- return
	#....................................
	$order{status_ok} 		= 1;
	$order{status_code} 	= 0;
	$order{status_message}	= "Aproved";
	&log_debug_add("type=securedata_cc_set,ok=1,service_id=$service_id",%order);
	return %order;
}
sub multilevel_securedata_cc_get(){
	local($service_id,$tags) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData,$debug,$debug_id,$cim_payment_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,%order,$sql);
	$order{check_cim_profile}	= 0;
	$order{check_cim_profile}	= (index("\U,$tags,",",CHECK_CIM,") ne -1) ? 1 : $order{check_cim_profile};
	$order{check_cim_profile}	= (index("\U,$tags,",",DO_NOT_CHECK_CIM,") ne -1) ? 0 : $order{check_cim_profile};
	$order{check_cc_error}		= 1;
	$order{check_cc_error}		= (index("\U,$tags,",",CHECK_CC_ERROR,") ne -1) ? 1 : $order{check_cc_error};
	$order{check_cc_error}		= (index("\U,$tags,",",DO_NOT_CHECK_CC_ERROR,") ne -1) ? 0 : $order{check_cc_error};
	$order{status_ok} 			= 0;
	$order{status_code} 		= 0;
	$order{status_cim_checked} 	= 0;
	$order{status_message}		= "Unknown";
	#
	#....................................
	# verifica service_id
	#....................................
	$service_id = clean_int($service_id);
	if ($service_id eq "") {
		$order{status_code} 	= 1;
		$order{status_message}	= "no service_id";
		return %order;
	}
	$cim_profile_id = &data_get("service_data",$service_id,"CIM_ID");
	if ($cim_profile_id eq "") {
		$order{status_code} 	= 2;
		$order{status_message}	= "No CIM profile id";
		return %order;
	}
	$order{customerProfileId} = $cim_profile_id;
	#
	#....................................
	#- get from database
	#....................................
	$sql = "
	SELECT 1,1,id,ani,cc_error,cc_type,cc_number,cc_fingerprint,cc_date,cc_code,first_name,last_name,address,country,city,state,zip,is_auto_recharge
	FROM service_profile_cc
	where service_id='$service_id' and active=1
	";
	%tmp_hash = database_select_as_hash($sql,"flag,id,ani,cc_error,cc_type,cc_number,cc_fingerprint,cc_date,cc_code,first_name,last_name,address,country,city,state,zip,is_auto_recharge");
	if ($tmp_hash{1}{flag} eq 1) {
		$order{contact_number}	= $tmp_hash{1}{ani};
		$order{cc_id}			= $tmp_hash{1}{id};
		$order{cc_error}		= $tmp_hash{1}{cc_error};
		$order{cc_type}			= $tmp_hash{1}{cc_type};
		$order{cc_number}		= $tmp_hash{1}{cc_number};
		$order{cc_fingerprint}	= $tmp_hash{1}{cc_fingerprint};
		$order{cc_date}			= $tmp_hash{1}{cc_date};
		$order{cc_code}			= $tmp_hash{1}{cc_code};
		$order{first_name}		= $tmp_hash{1}{first_name};
		$order{last_name}		= $tmp_hash{1}{last_name};
		$order{address}			= $tmp_hash{1}{address};
		$order{country}			= $tmp_hash{1}{country};
		$order{city}			= $tmp_hash{1}{city};
		$order{state}			= $tmp_hash{1}{state};
		$order{zip}				= $tmp_hash{1}{zip};
		$order{is_auto_recharge}= $tmp_hash{1}{is_auto_recharge};

	} else {
		$order{status_code} 	= 6;
		$order{status_message}	= "No active CC info for service_id=$service_id";
		return %order;
	}
	#
	#....................................
	#- check cc error
	#....................................
	if ($order{check_cc_error} eq 1) {
		$order{status_cc_error_checked} 	= 1;
		if ($order{cc_error} ne 0) {
			$order{status_code} 	= 7;
			$order{status_message}	= "CC flaged with error";
			return %order;
		}
	}
	#
	#....................................
	#- check CIM profile
	#....................................
	if ($order{check_cim_profile} eq 1) {
		$order{status_cim_checked} 	= 1;
		#
		#....................................
		#- ler CIM profile
		#....................................
		$MyData = &authorize_cim_transaction("getCustomerProfileRequest","<customerProfileId>$cim_profile_id</customerProfileId>");
		$cim_payment_id = $MyData->{profile}->{paymentProfiles}->{customerPaymentProfileId};
		if ($MyData->{STATUS_OK} eq 0) {
			$order{status_code} 	= 3;
			$order{status_message}	= "unknown CIM profile id $cim_profile_id";
			return %order;
		}
		if ($cim_payment_id eq "") {
			$order{status_code} 	= 4;
			$order{status_message}	= "No CIM payment profile id";
			return %order;
		}
		$order{customerPaymentProfileId} = $cim_payment_id;
		#
		#....................................
		#- se service id diferente, chama multilevel_securedata_wipe_on_error e retorna
		#....................................
		if ($MyData->{profile}->{merchantCustomerId} ne $service_id) {
			#&multilevel_securedata_clean_bad_links($service_id,$cim_profile_id);
			$order{status_code} 	= 5;
			$order{status_message}	= "incorrect CIM profile_id=$cim_profile_id and service_id";
			return %order;
		}
		#
		#....................................
		#- TODO: se cartao do banco diferente do cartao do cim, retorna erro.
		#....................................
	}
	#
	#....................................
	#- return
	#....................................
	$order{status_ok} 		= 1;
	$order{status_code} 	= 0;
	$order{status_message}	= "CIM profile found";
	return %order;
}
sub multilevel_securedata_cc_charge(){
	local($service_id) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData,$debug,$debug_id,$cim_payment_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,%order);
	$order{status_ok} 		= 0;
	$order{status_code} 	= 0;
	$order{status_message}	= "Unknown";
}
#
#------------------------
# misc
#------------------------
sub multilevel_dialstring_get(){
	#
	# this old version do not use new rate tables. 
	# we nd kill all references to this shit and delete 
	#
	local($n) = @_;
	local($tmp,$f,$s,$out,$cc);
	$cl = "|1|1242|1246|1264|1268|1284|1340|1345|1441|1473|1649|1664|1670|1671|1684|1758|1767|1784|1787|1809|1829|1868|1869|1876|1939|20|212|213|216|218|220|221|222|223|224|225|226|227|228|229|230|231|232|233|234|235|236|237|238|240|241|243|244|245|246|247|248|249|250|251|252|253|254|255|256|257|258|259|260|261|262|263|264|265|266|267|268|269|27|290|291|297|298|299|30|31|32|33|34|350|351|352|353|354|355|356|357|358|359|36|370|371|372|373|374|375|376|377|378|379|380|381|385|386|387|389|39|40|41|417|42|420|421|43|44|45|46|47|48|49|500|501|502|503|504|505|506|507|508|509|51|52|53|54|55|56|57|58|590|591|592|593|594|595|596|597|598|599|60|61|62|63|64|65|66|67|670|671|672|673|674|675|676|677|678|679|680|681|682|683|684|685|686|687|688|689|690|691|692|7|81|82|84|852|853|855|86|871|872|873|874|880|886|90|91|92|93|94|95|960|961|962|963|964|965|966|967|968|971|972|973|974|975|976|977|98|992|993|994|995|996|998|";
	$out = "";
	foreach $i (0..9){
		$f = &data_get("system_config","router","filter_".$i);
		if ($f ne "") {
			if (substr($f,-1,1) eq ".") {
				if ($n ne substr($f,0,-1)) {next}
			} else {
				if (index($n,$f) ne 0) {next}
			}
		}
		$out = &data_get("system_config","router","string_".$i);
		if ($out eq "") {next}
		last
	}
	if ($out ne "") {
		$tmp1	= "FULL";
		$tmp2	= $n;
		$out	=~ s/$tmp1/$tmp2/g;
		if ( (index($out,"COUNTRY") ne -1) || (index($out,"NUMBER") ne -1) ) {
			$cc = "";
			foreach $index (0..4) {	if ( index($cl,"|".substr($n,0,$index)."|") ne -1) {$cc = substr($n,0,$index);} }
			if ($cc ne "") {
				$nu = substr($n,length($cc),1000);
				$tmp1	= "COUNTRY";
				$tmp2	= $cc;
				$out	=~ s/$tmp1/$tmp2/g;
				$tmp1	= "NUMBER";
				$tmp2	= $nu;
				$out	=~ s/$tmp1/$tmp2/g;
			}
		}
	}
	return "SIP/$out";
}
sub multilevel_check_E164_number(){
	#
	# send a number (011, 10 digits usa, whatever)
	# return E164,country,flag_ok,error_msg
	#
	local($number) = @_;
	local($has_plus,$country,$tmp1,$tmp2,$tmp,%hash,$original_number);
	$original_number = $number;
	#
	# get country list
	if ($app{country_buffer} eq "") {
	    %hash = database_select_as_hash("select code,name from country ");
	    $app{country_buffer} = "|";
		$app{country_max_length} = 0;
	    foreach (keys %hash) {
			$app{country_buffer} .= "$_|";
			$app{country_max_length} = (length($_)>$app{country_max_length}) ? length($_) : $app{country_max_length};
		}
	}
	#
	# no empty number
	$number = trim(substr($number,0,1024));
	if ($number eq "") { return("EMPTY",$original_number,"") }
	#
	# if number is dirt, flag error
	$has_plus = (substr($number,0,1) eq "+") ? 1 : 0;
	$tmp1="-"; $tmp2=""; $number =~ s/$tmp1/$tmp2/g;
	$tmp1="+"; $tmp2=""; $number =~ s/\+/$tmp2/g;
	$number = clean_int($number);
	$number = ($has_plus eq 1) ? "+$number" : $number;
	#
	# if no E164, transform in E164 number
	if (substr($number,0,1) ne "+")  {
		#
		# if 7 digits, probably some on push USA without areacode
		if (length($number) eq 7)  { return("USANOAREACODE",$original_number,"") }
		#
		# transform USA number in E164 number
		if (substr($number,0,3) eq "011") {
			$number = "+".substr($number,3,100);
		} else {
			if (length($number) eq 10) {
				$number = "+1$number";
			} elsif ( (substr($number,0,1) eq "1") && (length($number) eq 10) ) {
				$number = "+$number";
			} else {
				# maybe wrong, but lets guess
				$number = "+$number";
			}
		}
	}
	#
	# check country code
	$country = "";
	foreach $tmp (1..$app{country_max_length}) {
		$tmp1 = substr($number,1,$tmp);
		if (index($app{country_buffer},"|$tmp1|") ne -1) {$country = $tmp1;}
	}
	if ($country eq "")  { return("UNKNOWNCOUNTRY",$original_number,"") }
	return("OK",substr($number,1,1000),$country);
}
#
#------------------------
# suspicious
#------------------------
sub multilevel_suspicious_check_test(){
	local (%info) = @_;
	local (%hash,%hash1,%hash2,$tmp,$tmp1,$tmp2,$sql);
	$info{status_is_suspicious}				= 0;
	$info{status_flaged_as_suspicious}		= 0;
	$info{status_error} 					= 0;
	$info{status_message} 					= "Not checked";
	$info{debug} 							= "";
	$info{adm_user_id}						= &clean_int($info{adm_user_id});
	$info{call_log_id}						= &clean_int($info{call_log_id});
	$info{change_status_if_suspicious} 		= ($info{change_status_if_suspicious} eq 1) ? 1 : 0;
	$info{switch_on_suspicious} 			= "";
	$info{switch_on_suspicious_threshold} 	= 1;
	$info{suspicious_counter} 				= 0;
	if (index("\L,$info{context},",",call_flood,") ne -1) {
		$info{context} .= ",call_flood_cross_service_dst_in_7days";
		$info{context} .= ",call_flood_minutes_in_24hrs";
		$info{context} .= ",call_flood_calls_in_1hr";
		$info{context} .= ",ani_channels_limit";
	}
	#
	#==============================================================
	# verifica service_id
	#==============================================================
	$info{debug} .= "Check service_id=$info{service_id} ! ";
	$info{service_id} = &clean_int($info{service_id});
	if ($info{service_id} eq ""){
		$info{status_error} 	= 1;
		$info{status_message} 	= "Error";
		$info{debug} .= "Empty! ";
		return %info;
	}
    $sql = "
		select
			1,1,
			service_status.switch_on_suspicious,
			service_status.call_flood_minutes_in_24hrs,
			service_status.call_flood_calls_in_1hr,
			service_status.call_flood_cross_service_dst_in_7days
		from
			service,service_status
		where
			service.id='$info{service_id}' and service_status.id=service.status
		";
    %hash = database_select_as_hash($sql,"flag,switch_on_suspicious,call_flood_minutes_in_24hrs,call_flood_calls_in_1hr,call_flood_cross_service_dst_in_7days");
    if ($hash{1}{flag} ne 1) {
		$info{status_error} 	= 1;
		$info{status_message} 	= "Error";
		$info{debug} .= "I cannot read! ";
		return %info;
	}
	$info{switch_on_suspicious} 					= $hash{1}{switch_on_suspicious};
	$info{call_flood_minutes_in_24hrs} 				= $hash{1}{call_flood_minutes_in_24hrs};
	$info{call_flood_calls_in_1hr} 					= $hash{1}{call_flood_calls_in_1hr};
	$info{call_flood_cross_service_dst_in_7days} 	= $hash{1}{call_flood_cross_service_dst_in_7days};
	$info{debug} .= "Found ! ";
	#
	#
	#==============================================================
	# get ANI, DST if noting from info
	#==============================================================
	if ( ($info{service_ani} eq "") || ($info{service_dst} eq "")  )  {
		$sql = "select 1,1,ani,dst from calls where service_id='$info{service_id}' order by id desc limit 0,1";
		%hash = database_select_as_hash($sql,"flag,ani,dst");
		$info{service_ani} = (($info{service_ani} eq "") && ($hash{1}{flag} eq 1) && ($hash{1}{ani} ne "")) ? $hash{1}{ani} : $info{service_ani};
		$info{service_dst} = (($info{service_dst} eq "") && ($hash{1}{flag} eq 1) && ($hash{1}{dst} ne "")) ? $hash{1}{dst} : $info{service_dst};
	}
	$info{debug} .= "using ANI=$info{service_ani} ! using DST=$info{service_dst} ! ";
	#
	#
	#==============================================================
	# check context SERVICE_ID_CHANNELS_LIMIT (replace ANI_CHANNELS_LIMIT)
	#==============================================================
	if ( (index("\L,$info{context},",",ani_channels_limit,") ne -1) && ($info{service_ani} ne "") ) {
		if ($is_agi_script eq 1) {
			$info{debug} .= "check service_id_channels_limit ! ";
			#
			# get active calls with SAME service id in log table
			$sql = "SELECT 1,1,count(*) FROM calls_log where datetime_stop is null and datetime_start>date_sub(now(),interval 4 hour) and service_id='$info{service_id}' ";
			%hash = database_select_as_hash($sql,"flag,value");
			if ($hash{1}{flag} ne 1) {
				&action_history("suspicious:sicerror",('service_id'=>$info{service_id},'call_log_id'=>$info{call_log_id}));
			}
			$info{debug} .= "sql= $sql ! ";
			$info{debug} .= "flag= $hash{1}{flag} ! ";
			$info{debug} .= "value= $hash{1}{value} ! ";
			$tmp = (($hash{1}{flag} eq 1) && ($hash{1}{value} >0)) ? $hash{1}{value} : 0;
			if ($tmp > 1) {
				$info{debug} .= "$tmp active calls from this ANI ! ";
				$info{status_is_suspicious}		= 1;
				$info{status_message} 			= "Suspicious";
				$info{suspicious_flags}{acl}++;
				&action_history("suspicious:siccatch",('value_old'=>$tmp,'service_id'=>$info{service_id},'call_log_id'=>$info{call_log_id}));
			} else {
				$info{debug} .= "no active calls from this service_id ! ";
			}
		} else {
			$info{debug} .= "This is not AGI script, no way to check active calls ! ";
		}
	} else {
		$info{debug} .= "no need ani_channels_limit ! ($info{service_ani}) ($info{context})!";
	}
	#
	#
	#==============================================================
	# check context ANI_CHANNELS_LIMIT
	#==============================================================
	if ( (index("\L,$info{context},",",ani_channels_limit,") ne -1) && ($info{service_ani} ne "") ) {
		if ($is_agi_script eq 1) {
			$info{debug} .= "check ani_channels_limit ! ";
			$tmp = &asterisk_count_active_ani($info{service_ani});
			if ($tmp > 1) {
				$info{debug} .= "$tmp active calls from this ANI ! ";
				$info{status_is_suspicious}		= 1;
				$info{status_message} 			= "Suspicious";
				$info{suspicious_flags}{acl}++;
			} else {
				$info{debug} .= "no active calls from this ANI ! ";
			}
		} else {
			$info{debug} .= "This is not AGI script, no way to check active calls ! ";
		}
	} else {
		$info{debug} .= "no need ani_channels_limit ! ($info{service_ani}) ($info{context})!";
	}
	#
	#
	#==============================================================
	# check context call_flood_cross_service_dst_in_7days
	#==============================================================
	if ( (index("\L,$info{context},",",call_flood_cross_service_dst_in_7days,") ne -1) && ($info{call_flood_cross_service_dst_in_7days} > 0) ) {
		$info{debug} .= "Check call_flood_cross_service_dst_in_7days ! ";
		#$sql = "
		#select
		#	1,1,count(*)
		#from
		#	calls,service,service_status
		#where
		#	calls.service_id=service.id and
		#	service.status = service_status.id and
		#	calls.date>date_sub(now(),interval 7 day) and
		#	FIND_IN_SET('with_recharge',service_status.tags)=0 and
		#	service.id <> '$info{service_id}' and
		#	calls.dst = '$info{service_dst}'
		#";
		$sql = "
		select
			1,1,count(*)
		from
			calls
		where
			calls.date>date_sub(now(),interval 7 day) and
			calls.service_id <> '$info{service_id}' and
			calls.dst = '$info{service_dst}'
		";
		#$sql = "
		#select
		#	1,1,count(*)
		#from
		#	calls_log
		#where
		#	datetime_start>date_sub(now(),interval 7 day) and
		#	dst = '$info{service_dst}'
		#";
		%hash = database_select_as_hash($sql,"flag,value");
		$tmp = (($hash{1}{flag} eq 1) && ($hash{1}{value} >0)) ? $hash{1}{value} : 0;
		$info{debug} .= "count=$tmp limit=$info{call_flood_cross_service_dst_in_7days} ! ";
		if ($tmp >= $info{call_flood_cross_service_dst_in_7days}) {
			$info{debug} .= " suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{cfcsdi7d}++;
		}
	} else {
		$info{debug} .= "no need call_flood_cross_service_dst_in_7days ($info{call_flood_cross_service_dst_in_7days}) ! ";
	}
	#
	#
	#==============================================================
	# check context call_flood_minutes_in_24hrs
	#==============================================================
	if ( (index("\L,$info{context},",",call_flood_minutes_in_24hrs,") ne -1) && ($info{call_flood_minutes_in_24hrs} > 0) ) {
		$info{debug} .= "Check call_flood_minutes_in_24hrs ! ";
		$sql = "
			select 1,1,sum(calls.seconds)
			from calls
			where date>date_sub(now(),interval 24 hour) and service_id = '$info{service_id}'
		";
		%hash = database_select_as_hash($sql,"flag,value");
		$tmp = (($hash{1}{flag} eq 1) && ($hash{1}{value} >0)) ? $hash{1}{value} : 0;
		$tmp = int($tmp/60);
		$info{debug} .= "minutes=$tmp limit=$info{call_flood_minutes_in_24hrs} ! ";
		if ($tmp >= $info{call_flood_minutes_in_24hrs}) {
			$info{debug} .= " suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{cfmi24h}++;
		}
	} else {
		$info{debug} .= "no need call_flood_minutes_in_24hrs ($info{call_flood_minutes_in_24hrs}) ! ";
	}
	#
	#
	#==============================================================
	# check context call_flood_calls_in_1hr
	#==============================================================
	if ( (index("\L,$info{context},",",call_flood_calls_in_1hr,") ne -1) && ($info{call_flood_calls_in_1hr} > 0) ) {
		$info{debug} .= "Check call_flood_calls_in_1hr ! ";
		$sql = "
			select 1,1,count(*)
			from calls_log 
			where datetime_start>date_sub(now(),interval 1 hour) and service_id = '$info{service_id}'
		";
		%hash = database_select_as_hash($sql,"flag,value");
		$tmp = (($hash{1}{flag} eq 1) && ($hash{1}{value} >0)) ? $hash{1}{value} : 0;
		$info{debug} .= "calls=$tmp limit=$info{call_flood_calls_in_1hr} ! ";
		if ($tmp >= $info{call_flood_calls_in_1hr}) {
			$info{debug} .= " suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{cfci1h}++;
		}
	} else {
		$info{debug} .= "no need call_flood_calls_in_1hr ($info{call_flood_calls_in_1hr}) ! ";
	}
	#
	#
	#==============================================================
	# check context = BILLING
	#==============================================================
	if (index("\L,$info{context},",",billing,") ne -1) {
		#
		#---------------------------------------
		# multiple credit card with single service
		#---------------------------------------
		$info{debug} .= "Check multiple credit card with single service ! ";
		$sql = "
			SELECT card_fingerprint,count(*)
			FROM credit_detail_authorize
			where service_id='$info{service_id}' and credit_id <> ''
			group by card_fingerprint
		";
		%hash = &database_select_as_hash($sql,"count");
		$tmp = 0;
		foreach (keys %hash) {
			$tmp += ($hash{$_}{count}>=1) ? 1 : 0
		}
		if ($tmp > 1) {
			$info{debug} .= "suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{mccwss}++;
		}
		#
		#---------------------------------------
		# multiple service with single credit card
		#---------------------------------------
		$info{debug} .= "check multiple service with single credit card ! ";
		$sql = "
			select card_fingerprint,1
			from credit_detail_authorize
			where service_id='$info{service_id}' and credit_id <> ''
			group by card_fingerprint
			order by max(timestamp) desc
			limit 0,2
		";
		%hash1 = &database_select_as_hash($sql,"flag");
		$tmp = 0;
		foreach $card_fingerprint (keys %hash1) {
			$sql = "
				select service_id,count(*)
				from credit_detail_authorize
				where card_fingerprint='$card_fingerprint' and service_id<>'$info{service_id}' and credit_id <> ''
				group by service_id
			";
			%hash2 = &database_select_as_hash($sql,"count");
			$info{detail}{debug} .= "$sql<hr>";
			foreach (keys %hash2) {
				if ($hash2{$_}{count}>=1) {
					$info{detail}{mswscc}{$card_fingerprint}{$_} += $hash2{$_}{count};
					$tmp++;
				}
			}
		}
		if ($tmp >= 1) {
			$info{debug} .= "suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{mswscc}++;
		}
		#
		#---------------------------------------
		# too many credit card errors
		#---------------------------------------
		$info{debug} .= "check too many credit card errors ! ";
		$sql = "
			SELECT 1,1,count(*)
			FROM credit_detail_authorize
			where service_id='$info{service_id}' and credit_id is null and timestamp>date_sub(now(),interval 7 day)
		";
		%hash = &database_select_as_hash($sql,"flag,count");
		if ( ($hash{1}{flag} eq 1) && ($hash{1}{count} >= 3) ) {
			$info{debug} .= "suspicious ! ";
			$info{status_is_suspicious}		= 1;
			$info{status_message} 			= "Suspicious";
			$info{suspicious_flags}{tmcce}++;
		}
	} else {
		$info{debug} .= "no need billing_check ! ";
	}
	#
	#
	#==============================================================
	# get title and description for each suspicious flag
	#==============================================================
	$info{debug} .= "RETURN ! ";
	foreach $tmp1 (keys %{$info{suspicious_flags}}) {
		$tmp2 = "suspicious:".$tmp1;
		%hash = &database_select_as_hash("SELECT 1,1,title FROM system_action_log_type where id='$tmp2'","flag,value");
		$info{suspicious_names}{$tmp1} =  ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) ? $hash{1}{value} : "Unknown suspicious flag code=$tmp1";
		$info{debug} .= "flagged $tmp1 - $info{suspicious_names}{$tmp1} ! ";
	}
	#
	#
	#==============================================================
	# do the action
	#==============================================================
	if ( ($info{status_is_suspicious} eq 1) && ($info{change_status_if_suspicious} eq 1) ) {
		$info{debug} .= "log suspicious ! ";
		foreach $tmp (keys %{$info{suspicious_flags}}) {
			%hash = &database_select_as_hash("SELECT 1,1,title FROM system_action_log_type where id='suspicious:$tmp'","flag,value");
			$info{suspicious_names}{$tmp} =  ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) ? $hash{1}{value} : "Unknown suspicious flag code=$tmp1";
			&action_history("suspicious:".$tmp,('service_id'=>$info{service_id},'call_log_id'=>$info{call_log_id},'adm_user_id'=>$info{adm_user_id}));
			$info{debug} .= "detect  ! ";
		}
		$info{debug} .= "try to flag as suspicious ! ";
		if ($info{switch_on_suspicious} eq "") {
			$info{debug} .= "I cannot flag this service as suspicious ! ";
			$info{status_message} 		= "Suspicious";
			$info{suspicious_flags}{error}++;
			&action_history("suspicious:error",('service_id'=>$info{service_id},'call_log_id'=>$info{call_log_id},'adm_user_id'=>$info{adm_user_id}));
		} else {
			# change status
			%hash2 = database_select_as_hash("SELECT 1,1,service.status,service_status.name FROM service_status,service where service.status=service_status.id and service.id='$info{service_id}' ","flag,id,name");
			$tmp1 = ($hash2{1}{flag} eq 1) ? $hash2{1}{name} : "Unknown";
			$tmp2 = ($hash2{1}{flag} eq 1) ? $hash2{1}{id} : "";
			if ($tmp2 ne $info{switch_on_suspicious}) {
				&database_do("update service set service.status=$info{switch_on_suspicious} where service.id='$info{service_id}' ");
				%hash2 = database_select_as_hash("SELECT 1,1,service_status.name FROM service_status,service where service.status=service_status.id and service.id='$info{service_id}' ","flag,value");
				$tmp2 = ($hash2{1}{flag} eq 1) ? $hash2{1}{value} : "Unknown";
				&action_history("suspicious:status:change",('service_id'=>$info{service_id},'call_log_id'=>$info{call_log_id},'adm_user_id'=>$info{adm_user_id}, 'value_old'=>$tmp1, 'value_new'=>$tmp2));
				$info{status_flaged_as_suspicious} = 1;
				$info{debug} .= "flagged ! ";
			}
		}
	}
	#
	#
	#==============================================================
	# return
	#==============================================================
	return %info;
}
sub multilevel_suspicious_check(){
	local (%info) = @_;
	local (%hash,%hash1,%hash2,$tmp,$tmp1,$tmp2,$sql);
	$info{status_is_suspicious}					= 0;
	$info{status_warning}						= 0;
	$info{status_flaged_as_suspicious}			= 0;
	$info{status_error} 						= 0;
	$info{status_message} 						= "Not checked";
	$info{debug} 								= "";
	$info{adm_user_id}							= &clean_int($info{adm_user_id});
	$info{force_suspicious_if_no_validated_ani} = ($info{force_suspicious_if_no_validated_ani} eq 1) ? 1 : 0;
	$info{check_no_validated_ani} 				= 0;
	$info{no_action} 							= ($info{no_action} eq 1) ? 1 : 0;
	#
	#-----------------------------------
	# verifica service_id
	#-----------------------------------
	$info{debug} .= "Check service_id=$info{service_id} ! ";
		$info{service_id} = &clean_int($info{service_id});
	if ($info{service_id} eq ""){
		$info{status_error} 		= 1;
		$info{status_message} 		= "Error";
		$info{debug} .= "Empty! ";
		return %info;
	}
    $sql = "
		select 1,1,service_status.switch_on_suspicious, service_status.need_ani_check, service_status.switch_on_first_credit
		from service,service_status
		where service.id='$info{service_id}' and service_status.id=service.status
		";
    %hash = database_select_as_hash($sql,"flag,switch_on_suspicious,need_ani_check,switch_on_first_credit");
    if ($hash{1}{flag} ne 1) {
		$info{status_error} 		= 1;
		$info{status_message} 		= "Error";
		$info{debug} .= "I cannot read! ";
		return %info;
	}
	$info{switch_on_suspicious} 	= $hash{1}{switch_on_suspicious};
	$info{check_no_validated_ani}= ( ($hash{1}{switch_on_first_credit} ne "") && ($hash{1}{need_ani_check} eq 1)  ) ? 1 : 0;
	$info{debug} .= "Found ! $sql ! ";
	$info{debug} .= "switch_on_suspicious=$info{switch_on_suspicious} ! ";
	$info{debug} .= "check_no_validated_ani=$info{check_no_validated_ani} ! ";
	#
	#---------------------------------------
	# check multiple cards in one service
	#---------------------------------------
	$info{debug} .= "Multiple card in one service ! ";
	$sql = "
		SELECT card_fingerprint,count(*)
		FROM credit_detail_authorize
		where service_id='$info{service_id}' and credit_id <> ''
		group by card_fingerprint
	";
	%hash = &database_select_as_hash($sql,"count");
	$tmp = 0;
	foreach (keys %hash) {
		$tmp += ($hash{$_}{count}>=1) ? 1 : 0
	}
	if ($tmp > 1) {
		$info{status_is_suspicious}		= 1;
		$info{status_message} 			= "Suspicious";
		$info{suspicious_flags}{mccwss}++;;
	}
	#
	#---------------------------------------
	# check multiple services in last cards
	#---------------------------------------
	$info{debug} .= "multiple services in last card ! ";
	$sql = "
		select card_fingerprint,1
		from credit_detail_authorize
		where service_id='$info{service_id}' and credit_id <> ''
		group by card_fingerprint
		order by max(timestamp) desc
		limit 0,2
	";
	%hash1 = &database_select_as_hash($sql,"flag");
	$tmp = 0;
	foreach $card_fingerprint (keys %hash1) {
		$sql = "
			select service_id,count(*)
			from credit_detail_authorize
			where card_fingerprint='$card_fingerprint' and service_id<>'$info{service_id}' and credit_id <> ''
			group by service_id
		";
		%hash2 = &database_select_as_hash($sql,"count");
		$info{detail}{debug} .= "$sql<hr>";
		foreach (keys %hash2) {
			if ($hash2{$_}{count}>=1) {
				$info{detail}{mswscc}{$card_fingerprint}{$_} += $hash2{$_}{count};
				$tmp++;
			}
		}
	}
	if ($tmp >= 1) {
		$info{status_is_suspicious}		= 1;
		$info{status_message} 			= "Suspicious";
		$info{suspicious_flags}{mswscc}++;
	}
	#
	#---------------------------------------
	# check limit em authorize errors tmcce
	#---------------------------------------
	$sql = "
		SELECT 1,1,count(*)
		FROM credit_detail_authorize
		where service_id='$info{service_id}' and credit_id is null and timestamp>date_sub(now(),interval 7 day)
	";
	%hash = &database_select_as_hash($sql,"flag,count");
	if ( ($hash{1}{flag} eq 1) && ($hash{1}{count} >= 3) ) {
		$info{status_is_suspicious}		= 1;
		$info{status_message} 			= "Suspicious";
		$info{suspicious_flags}{tmcce}++;
	}
	#
	#---------------------------------------
	# check no checked ANI
	#---------------------------------------
	$info{debug} .= "force_suspicious_if_no_validated_ani=$info{force_suspicious_if_no_validated_ani}! ";
	$info{debug} .= "check_no_validated_ani=$info{check_no_validated_ani}! ";
	if ( ($info{force_suspicious_if_no_validated_ani} eq 1) || ($info{check_no_validated_ani} eq 1) ){
		$info{debug} .= "check no ani! ";
		$tmp = 0;
		foreach $index (1..20) {
			$tmp1 = &data_get("service_data",$info{service_id},"ani_".$index."_number");
			$info{debug} .= "$index ! ";
			if ($tmp1 ne "") {
				$tmp2 = &data_get("service_data",$info{service_id},"ani_".$index."_number_validated");
				$tmp = ( ($tmp1 eq $tmp2) && ($tmp2 ne "")  ) ? 1 : $tmp;
				$info{debug} .= "$tmp $tmp1 $tmp2 ! ";
			}
		}
		$info{debug} .= "final tmp=$tmp ! ";
		if ($tmp eq 0) {
			$info{debug} .= "no ani ! ";
			if ($info{force_suspicious_if_no_validated_ani} eq 1) {
				$info{debug} .= "suspicious ! ";
				$info{status_is_suspicious}		= 1;
				$info{status_message} 			= "Suspicious";
				$info{suspicious_flags}{nva}++;
			} else {
				$info{debug} .= "warning ! ";
				$info{status_warning}		= 1;
				$info{status_message} 		= "Warning";
				$info{suspicious_flags}{nva}++;
			}
		}
	}
	#
	#---------------------------------------
	# flag suspicious se necessario
	#---------------------------------------
	if ($info{status_is_suspicious} eq 1){
		if ($info{switch_on_suspicious} eq "") {
			$info{status_message} 		= "Suspicious";
			$info{suspicious_flags}{error}++;
			if ($info{no_action} eq 0) {
				# log suspicious error only
				&action_history("suspicious:error",('service_id'=>$info{service_id},'adm_user_id'=>$info{adm_user_id}));
			}
		} else {
			if ($info{no_action} eq 0) {
				#
				# log all suspicious errors
				foreach $tmp (keys %{$info{suspicious_flags}}) {
					&action_history("suspicious:".$tmp,('service_id'=>$info{service_id},'adm_user_id'=>$info{adm_user_id}));
				}
				#
				# change status
				%hash2 = database_select_as_hash("SELECT 1,1,service_status.name FROM service_status,service where service.status=service_status.id and service.id='$info{service_id}' ","flag,value");
				$tmp1 = ($hash2{1}{flag} eq 1) ? $hash2{1}{value} : "Unknown";
				&database_do("update service set service.status=$info{switch_on_suspicious} where service.id='$info{service_id}' ");
				%hash2 = database_select_as_hash("SELECT 1,1,service_status.name FROM service_status,service where service.status=service_status.id and service.id='$info{service_id}' ","flag,value");
				$tmp2 = ($hash2{1}{flag} eq 1) ? $hash2{1}{value} : "Unknown";
				#
				# log status changed
				&action_history("suspicious:status:change",('service_id'=>$info{service_id}, 'value_old'=>$tmp1, 'value_new'=>$tmp2));
				$info{status_flaged_as_suspicious} = 1;
			}
		}
	}
	#
	#---------------------------------------
	# return
	#---------------------------------------
	foreach $tmp1 (keys %{$info{suspicious_flags}}) {
		$tmp2 = "suspicious:".$tmp1;
		%hash = &database_select_as_hash("SELECT 1,1,title FROM system_action_log_type where id='$tmp2'","flag,value");
		$info{suspicious_flags}{$tmp1} =  ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) ? $hash{1}{value} : "Unknown suspicious flag code=$tmp1";
	}
	return %info;
}
#
#------------------------
# manage services
#------------------------
sub multilevel_service_create(){
	local(%data) = @_;
	local($sql,$db,$tmp,%commission_data);
	my @chars =('a'..'z');
	my @digits=('0'..'9');
	$data{ok} = 0;
	$data{message} = "";
	$data{invite_service_id} = $data{parent_service_id};
	#
	# valida se esse service id (ou blank)
	# TODO: se invalido, dar erro
	if ($data{parent_service_id} ne "") {
		$sql = "
		select 1,1,service.id
		from
		service
		where
		service.id = '$data{parent_service_id}'
		";
		%db = database_select_as_hash($sql,"flag,service_id");
		$data{parent_service_id} = ($db{1}{flag} eq 1) ? $db{1}{service_id} : "";
		$data{debug} .= "Using refer id=$data{invite_service_id}, ";
	}
	#
	# get new status
	$sql = "
	SELECT 1,1,service_status.refer_status
	FROM service,service_status,service_status as service_status_2
	where
	service.id='$data{parent_service_id}' and
	service.status = service_status.id and
	service_status.refer_status = service_status_2.id
	";
	%db = database_select_as_hash($sql,"flag,value");
	$data{service_new_status} = ( ($db{1}{value} ne "") && ($db{1}{flag} eq 1) ) ? $db{1}{value} : "";
	if ($data{service_new_status} eq "") {
		$data{ok} = 0;
		$data{message} = "I cannot create service with no referral status! Please try again in few minutes.";
		return %data;
	}
	#
	# create service
	$sql  = "insert into service (product_id,  status,                      email,           name,           creation_date,  last_change  )  ";
	$sql .= "             values ('1',         '$data{service_new_status}', '$data{email}',  '$data{name}',  now(),          now()        ) ";
 	database_do($sql);
	%db = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
	$data{service_id} = $db{1};
	$data{debug} .= "created service_id=$data{service_id}($db{1}) [$sql], ";
	if ($data{service_id} eq "") {
		$data{ok} = 0;
		$data{message} = "I cannot create service for this new client! Please try again in few minutes.";
		return %data;
	}
	#
	# add on tree
	if ($data{invite_service_id} ne "") {
		$sql  = "insert into service_tree (service_id,            parent_service_id          )  ";
		$sql .= "                  values ('$data{service_id}',  '$data{parent_service_id}'  ) ";
		database_do($sql);
		&data_set("service_data",$data{invite_service_id},"last_friend_time",time);
		$data{debug} .= "add on tree, ";
	}
	#
	# criar pin
	unless ($tmp=&multilevel_pin_create($data{service_id})) {
		$data{ok} = 0;
		$data{message} = "I cannot create pin for this new client! Please try again in few minutes";
		# TODO: apaga servico e tree do banco
		return %data;
	}
	$data{service_pin} = $tmp;
	$data{debug} .= "created pin=$data{service_pin}, ";
	#
	# criar invite
	unless ($tmp=&multilevel_invite_create($data{service_id})) {
		$data{ok} = 0;
		$data{message} = "I cannot create invite for this new client! Please try again in few minutes";
		# TODO: apaga servico, tree e pin do banco
		return %data;
	}
	$data{service_invite} = $tmp;
	$data{debug} .= "created invite_id=$data{service_invite}, ";
	#
	# new friend commission
	if ($data{invite_service_id} ne "") {
		#
		# old commission mode
		#$data{commission_value}				= &data_get("system_config","commission","newf_value");
		#$data{commission_mode} 				= &data_get("system_config","commission","newf_mode");
		#$data{commission_activation_date_1} = &data_get("system_config","commission","newf_activation_date_1");
		#$data{commission_activation_date_2} = &data_get("system_config","commission","newf_activation_date_2");
		#if ($data{commission_value} > 0)  {
		#	%commission_data = ();
		#	$commission_data{activation_date_1} = $data{commission_activation_date_1};
		#	$commission_data{activation_date_2} = $data{commission_activation_date_2};
		#	$commission_data{service_id}		= $data{parent_service_id};
		#	$commission_data{from_service_id}	= $data{service_id};
		#	$commission_data{value} 			= $data{commission_value};
		#	$commission_data{type} 				= "NEWF";
		#	$commission_data{email_template} 	= "alert.newf.commission";
		#	$commission_data{mode} 				= ($data{commission_mode} eq "ZENO") ? "ZENO" : "SINGLE";
		#	%commission_data = &multilevel_commission_aXdXd(%commission_data);
		#}
		#
		# NEW commission mode
		%commission_data = ();
		$commission_data{service_id}				= $data{parent_service_id};
		$commission_data{from_service_id}			= $data{service_id};
		$commission_data{commission_type_engine} 	= "REFERRAL_SIGNIN";
		%commission_data = &multilevel_commission_new(%commission_data);
	}
	#
	# return data
	$data{ok} = 1;
	$data{message} = "OK";
	return %data;
}
sub multilevel_service_get_parent(){
	local($service_id) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql,$out);
	%hash =	database_select_as_hash( &database_scape_sql("SELECT 1,1,service_id,parent_service_id FROM service_tree where service_id='%d' limit 0,1",$service_id) , "flag,service_id,parent_service_id");
	$out = ( ($hash{1}{flag} eq 1) && ($hash{1}{service_id} eq $service_id) && ($hash{1}{parent_service_id} ne "") ) ? $hash{1}{parent_service_id} : ""; 
	return $out;
}
sub multilevel_service_status_get_value(){
	local($service_id,$name) = @_;
	local($tmp,$sql,$tmp1,$tmp2,%hash,%hash1,%hash2,%data);
	$tmp = "";
	if (index("|can_enter_blacklisted_CC|can_enter_CC_active_in_another_service|","|$name|") ne -1){
		$sql = "SELECT 1,1,service_status.$name FROM service_status,service where service_status.id=service.status and service.id='$service_id' ";
		%hash = database_select_as_hash($sql,"flag,value");
		$tmp = ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) ? $hash{1}{value} : $tmp;
	}
	return $tmp
}
sub multilevel_service_status_change_if_need(){
	local($service_id,$switch_on_name) = @_;
	local($tmp,$tmp1,$tmp2,%hash,%hash1,%hash2,%data);
	if (index("|switch_on_enter_CC_active_in_another_service|switch_on_enter_blacklisted_CC|switch_on_dial_blacklisted_DST|switch_on_autorecharge_out|switch_on_autorecharge_in|switch_on_first_call|switch_on_first_credit|switch_on_suspicious|switch_on_autorecharge_ok_charge|","|$switch_on_name|") eq -1){return 0;}
	%hash = database_select_as_hash("SELECT 1,1,service_status.$switch_on_name , service_status.id, service_status.name FROM service_status,service where service_status.id = service.status and service.id='$service_id' ","flag,id_new,id_old,name_old");
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id_new} > 0) && ($hash{1}{id_new} ne "") ) {return 0}
	%data = %{$hash{1}};
	%hash = database_select_as_hash("SELECT 1,1,name FROM service_status where id='$data{id_new}' ","flag,name");
	$data{name_new} = "$data{id_new}:$hash{1}{name}";
	$data{name_old} = "$data{id_old}:$data{name_old}";
	if ($data{id_new} ne $data{id_old}) {
		&database_do("update service set last_change=now(),status='$data{id_new}' where id='$service_id'");
		&action_history("noc:service:status:change",('service_id'=>$service_id, 'value_new'=>$data{name_new} , 'value_old'=>$data{name_old} ));
		return 1;
	}
	return 0;
}
#
#------------------------
# new commission api
#------------------------
sub multilevel_commission_new(){
	local(%data) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,%service_commission,$zeno_loop);
	# 
	#--------------------------------------------------------------------
	# This funcion apply a commission to one service (and parents if neccessary), send email (TODO: we need enable email) and log action
	# We need send at least service_id (to apply commission) and commission_type_id (to get information how to apply)
	# commission_type.value_type=percentage need value_percentage_base  to calculate percentage
	# lets work...
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# start
	#--------------------------------------------------------------------
	$data{ok} 				= 0;
	$data{error_code} 		= 0;
	$data{error_message} 	= "";
	#
	#--------------------------------------------------------------------
	# get/check/verify service_id (stop if wrong)
	#--------------------------------------------------------------------
	$data{service_id} = &clean_int($data{service_id});
	if ($data{service_id} eq "") { 
		$data{error_code} 		= 101;
		$data{error_message}	= "No service_id";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
		return %data;
	}  
	%hash =	database_select_as_hash(
				&database_scape_sql(
					"select 1,1,id,name,email,age_id,age_is_manual from service where id='%d' ",
					$data{service_id}
				),
				"flag,id,name,email,age_id,age_is_manual"
			);
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $data{service_id}) ) { 
		$data{error_code} 		= 102;
		$data{error_message}	= "Bad service_id";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
		return %data;
	}  
	$data{service_name} 		= $hash{1}{name};
	$data{service_email}		= $hash{1}{email};
	$data{service_age_id}		= $hash{1}{age_id};
	$data{service_age_is_manual}= $hash{1}{age_is_manual};
	#
	#
	#--------------------------------------------------------------------
	# get/check/verify commission_type_id (stop if wrong)
	#--------------------------------------------------------------------
	if ($data{commission_type_engine} eq "MANUAL") {
		#
		#--------------------------------------------------------------------
		# manual dont check database, get all data from %data hash
		#--------------------------------------------------------------------
		#
		$data{debug} .= "MANUAL engine, lets check each fields ! ";
		$tmp1 = &clean_int($data{commission_type_days_to_convert_to_credit});
		$tmp1 = ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=99999) ) ? $tmp1 : 7;
		$data{commission_type_days_to_convert_to_credit} = $tmp1;
		$data{debug} .= "days_to_credit is now '$data{commission_type_days_to_convert_to_credit}' ! ";
		#
		$tmp1 = &clean_int($data{commission_type_days_to_convert_to_check});
		$tmp1 = ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=99999) ) ? $tmp1 : 90;
		$data{commission_type_days_to_convert_to_check} = $tmp1;
		$data{debug} .= "days_to_check is now '$data{commission_type_days_to_convert_to_check}' ! ";
		#
		$tmp1 = $data{commission_type_apply_mode};
		$tmp1 = (index("|SINGLE|ZENO|","|$tmp1|") eq -1) ? "SINGLE" : $tmp1;
		$data{commission_type_apply_mode} = $tmp1;
		$data{debug} .= "apply_mode is now '$data{commission_type_apply_mode}' ! ";
		#
		# ps: manual engine can only get value_type=value. 
		$data{commission_type_value_type} = "VALUE";
		$data{debug} .= "value_type is now 'VALUE' ! ";
		#
		$data{commission_type_value}++;
		$data{commission_type_value}--;
		$tmp1 = $data{commission_type_value};
		unless ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=100) ) {
			$data{error_code} 		= 151;
			$data{error_message}	= "Bad commission_type_value for manual engine. Valid range is 0-100";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
			return %data;
		}
	} else {
		#
		#--------------------------------------------------------------------
		# not manual so we need search at database (stop if wrong)
		#--------------------------------------------------------------------
		$data{commission_type_id} = &clean_int($data{commission_type_id});
		if ( ($data{commission_type_id} eq "") && ($data{commission_type_engine}) ) {
			$data{debug} .= "commission_type_id is empty but we have commission_type_engine='$data{commission_type_engine}'. Lets try guess commission_type_id ! ";
			$data{commission_type_id} = &multilevel_commission_new_get_type_id_by_engine_and_service_id($data{commission_type_engine},$data{service_id});
			$data{debug} .= "found commission_type_id='$data{commission_type_id}'  ! ";
			# 
			# to avoid database overflow, lets not log commissions with no definition
			if ($data{commission_type_id} eq "") { 
				$data{debug} .= "no commission found ! ";
				$data{ok} = 1;
				&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},service_id=$data{service_id}",%data);
				return %data;
			}
		}
		if ($data{commission_type_id} eq "") { 
			$data{error_code} 		= 111;
			$data{error_message}	= "No commission_type_id";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}  
		%hash =	database_select_as_hash(
					&database_scape_sql(
					"SELECT 1,1,id,engine,title,value,value_type,apply_mode,days_to_convert_to_credit,days_to_convert_to_check FROM service_commission_type where id='%d' ",
					$data{commission_type_id}
					),
					"flag,id,engine,title,value,value_type,apply_mode,days_to_convert_to_credit,days_to_convert_to_check"
				);
		unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $data{commission_type_id}) ) { 
			$data{error_code} 		= 112;
			$data{error_message}	= "Bad commission_type_id";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}  
		$data{commission_type_engine}						= $hash{1}{engine};
		$data{commission_type_value_search_phone_table}		= ( index("|REFERRAL_FIRST_CALL|REFERRAL_DIALOUT_DST|REFERRAL_DIALOUT_DID|SERVICE_FIRST_CALL|SERVICE_DIALOUT_DST|SERVICE_DIALOUT_DID|SERVICE_RADIO_DID|","|$data{commission_type_engine}|") eq -1 ) ? 0 : 1;
		$data{commission_type_days_to_convert_to_credit} 	= $hash{1}{days_to_convert_to_credit}; 
		$data{commission_type_days_to_convert_to_check}		= $hash{1}{days_to_convert_to_check}; 
		$data{commission_type_apply_mode}					= $hash{1}{apply_mode};
		$data{commission_type_value}						= $hash{1}{value};
		$data{commission_type_value_type}					= $hash{1}{value_type};		
	}
	#
	#--------------------------------------------------------------------
	# check extra fields (we need stop if wrong)
	#--------------------------------------------------------------------
	if ($data{commission_type_value_type} eq "PERCENTAGE") {
		if ($data{value_percentage_base} eq "") {
			$data{error_code} 		= 201;
			$data{error_message}	= "commission_type_value_type is PERCENTAGE but no value_percentage_base ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
		$data{value_percentage_base}++;
		$data{value_percentage_base}--;
		if ( ($data{value_percentage_base} < 0) || ($data{value_percentage_base} > 1000) ) {
			$data{error_code} 		= 202;
			$data{error_message}	= "invalid value_percentage_base (valid range 0-1000)";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
	}
	if ($data{commission_type_value_type} eq "PER_MINUTE") {
		if ($data{call_seconds} eq "") {
			$data{error_code} 		= 203;
			$data{error_message}	= "commission_type_value_type is PER_MINUTE but no call_seconds ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
		$data{call_seconds}++;
		$data{call_seconds}--;
		if ( ($data{call_seconds} < 0) || ($data{call_seconds} > (60*60*12) ) ) {
			$data{error_code} 		= 204;
			$data{error_message}	= "invalid call_seconds. valid range 0 to (60*60*12) ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
	}
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# clean some basic variables (we dont need stop if wrong, just fix)
	#--------------------------------------------------------------------
	$tmp1 = &clean_int($data{deep});
	$data{deep} = ( ($data{deep} ne "") && ($data{deep}>=0) && ($data{deep}<=99999) ) ? $data{deep} : 1;
	#if ($data{commission_type_engine} eq "MANUAL") {
	#} else {
	#	$data{deep} = 1;
	#}
	#
	#--------------------------------------------------------------------
	# calc commission_value. 
	# 1- get default value from commission_type, 
	# 2- search specific value at phone_table if need
	# 3- transform from percentage to money value if necessary 
	# 4- transform from per_minute to money value if necessary 
	# age discount dont apply here.. age shuld be per service, at multilevel_commission_new_for_one_service
	#--------------------------------------------------------------------
	# 
	# get default commission value from commission_type
	$data{debug} .= "calc commission value ! ";
	$data{commission_value} 		= $data{commission_type_value};
	$data{commission_value_type}	= $data{commission_type_value_type};
	$data{commission_value_base} 	= $data{commission_value};
	$data{commission_percentage}	= 100;
	$data{commission_seconds}		= $data{call_seconds};
	$data{debug} .= "Default value is '$data{commission_value}' ! ";
	#
	# search specific vaue by phone number
	if ($data{commission_type_value_search_phone_table} eq 1) {
		$data{debug} .= "We need try specific value for phone number='$data{call_number}' ! ";
		$tmp = &multilevel_commission_new_value_by_call_number($data{call_number},$data{commission_type_id});
		if ($tmp ne "") {
			$data{debug} .= "found '$tmp' ! ";
			$data{commission_value} = $tmp;
			$data{debug} .= "New value is now '$data{commission_value}' ! ";
		} else {
			$data{debug} .= "No specific value for this number ! ";
		}
	}
	#
	# if commission_type.value_type=percentage, use value as percentage of value_base  to find value
	if ($data{commission_type_value_type} eq "PERCENTAGE") {
		$data{debug} .= "commission_type_value_type is percentage ! ";
		$data{debug} .= "Using '$data{value_percentage_base}' to calc '$data{commission_value}' percent ! ";
		$data{commission_value_base} = $data{value_percentage_base};
		$data{commission_percentage} = $data{commission_value};
		$data{commission_value} = $data{commission_value_base}*($data{commission_value}/100);
		$data{debug} .= "New value is now '$data{commission_value}' ! ";
	}
	#
	# if commission_type.value_type=percentage, use value as percentage of value_base  to find value
	if ($data{commission_type_value_type} eq "BY_CALL_MINUTES") {
		$data{debug} .= "commission_type_value_type is per minute ! ";
		$data{debug} .= "Using '$data{commission_value}' rate per minute to calc '$data{call_seconds}' seconds value ! ";
		$data{commission_value} 	= ($data{commission_value}*($data{call_seconds}/60));
		$data{debug} .= "New value is now '$data{commission_value}' ! ";
	}
	#
	# re chech commission_value
	$data{debug} .= "Re-check commission value ! ";
	$tmp1 = $data{commission_value};
	unless ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=100) ) {
		$data{error_code} 		= 161;
		$data{error_message}	= "Bad commission_value. Valid range is 0-100";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
		return %data;
	}
	#
	$data{debug} .= "commission_value is '$data{commission_value}' ! ";
	$data{debug} .= "commission_value_type is '$data{commission_value_type}' ! ";
	$data{debug} .= "commission_value_base is '$data{commission_value_base}' ! ";
	$data{debug} .= "commission_value_percentage is '$data{commission_percentage}' ! ";
	$data{debug} .= "commission_value_default is '$data{commission_type_value}' ! ";
	$data{debug} .= "commission_call_seconds is '$data{commission_seconds}' ! ";
	$data{debug} .= "commission_call_number is '$data{call_number}' ! ";
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# abort with ok=1 if commission value is zero (no need log debug)
	#--------------------------------------------------------------------
	if ($data{commission_value} eq 0) {
		$data{debug} .= "commission_value is zero, no commission need ! ";
		$data{ok} = 1;
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},service_id=$data{service_id}",%data);
		return %data;
	}
	#
	#--------------------------------------------------------------------
	# find age_discount
	#--------------------------------------------------------------------
	$data{debug} .= "Find age discount ! ";
	$data{age_discount_percentage}		= 0;
	$data{age_discount_id}				= "";
	$data{age_discount_value_before}	= $data{commission_value};
	$data{age_discount_value_after}		= $data{commission_value};
	if ($data{commission_type_id} ne "") {
		$data{debug} .= "read age_discount_service_id=$data{age_discount_service_id} ! ";
		$data{debug} .= "read service_id=$data{service_id} ! ";
		$data{age_discount_service_id} 		= ($data{age_discount_service_id} ne "") ? $data{age_discount_service_id} : $data{service_id}; 
		$data{debug} .= "Use age_discount_service_id=$data{age_discount_service_id} ! ";
		$sql = &database_scape_sql(
				"
				select 
				1,1,
				service_commission_type_age_discount.discount_percentage, 
				service_commission_type.id, 
				service_commission_type.title
				from 
				service,service_commission_type_age_discount, service_commission_type
				where 
				service.id='%d' 
				and service_commission_type_age_discount.service_commission_type_id='%d'  
				and service_commission_type.id='%d'  
				and service_commission_type_age_discount.service_age_id=service.age_id 
 				",
				$data{service_id},$data{commission_type_id},$data{commission_type_id}
			);
		%hash =	database_select_as_hash($sql,"flag,value,age_id,title");
		if ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) { 
			$data{age_discount_percentage}	= $hash{1}{value};
			$data{age_discount_title}		= $hash{1}{title};
			$data{age_discount_id}			= $hash{1}{age_id};
			$data{debug} .= "Age discount found ! ";
			$data{debug} .= "Age discount id = $data{age_discount_id} ! ";
			$data{debug} .= "Age discount title = $data{age_discount_title} ! ";
			$data{debug} .= "Age discount percentage = $data{age_discount_percentage} ! ";
		}  else {
			$data{debug} .= "No age discount found for this service/commission type ! ";
			$data{debug} .= "$sql ! ";
		}
	} else {
		$data{debug} .= "No commission type ($data{commission_type_id}), so no age discount looking ! ";
	}
	if ($data{age_discount_percentage}>0) {
		$data{age_discount_value_before}	= $data{commission_value};
		$data{age_discount_value_after}		=  $data{age_discount_value_before} - ($data{age_discount_value_before}*($data{age_discount_percentage}/100));
		$data{commission_value}				= $data{age_discount_value_after};
		$data{debug} .= "Calc age discount ! ";
		$data{debug} .= "age_discount_value_before = $data{age_discount_value_before} ! ";
		$data{debug} .= "age_discount_percentage = $data{age_discount_percentage} ! ";
		$data{debug} .= "age_discount_value_after = $data{age_discount_value_after} ! ";
	}
	#
	#--------------------------------------------------------------------
	# apply commission
	#--------------------------------------------------------------------
	$data{log_references_commissions_id} 	= "";
	$data{log_references_service_id} 		= "";
	if ($data{commission_type_apply_mode} eq "SINGLE") {
		#
		#--------------------------------------------------------------------
		# apply_mode=SINGLE
		#--------------------------------------------------------------------
		$data{debug} .= "Apply commission in SINGLE mode ! ";
		%service_commission = ();
		$service_commission{service_id}					= $data{service_id};
		$service_commission{title}						= $data{commission_title};
		$service_commission{value}						= $data{commission_value};
		$service_commission{type_id}					= $data{commission_type_id};
		$service_commission{engine}						= $data{commission_type_engine};
		$service_commission{apply_mode}					= $data{commission_type_apply_mode};
		$service_commission{days_to_convert_to_credit}	= $data{commission_type_days_to_convert_to_credit};
		$service_commission{days_to_convert_to_check}	= $data{commission_type_days_to_convert_to_check};
		$service_commission{deep}						= $data{deep};
		$service_commission{percentage}					= 100;
		$service_commission{from_service_id}			= $data{from_service_id};
		$service_commission{credit_id}					= $data{credit_id};
		$service_commission{calls_id}					= $data{calls_id};
		$service_commission{value_type}					= $data{commission_type_value_type};
		$service_commission{value_default}				= $data{commission_type_value};
		$service_commission{value_base}					= $data{commission_value_base};
		$service_commission{value_percentage}			= $data{commission_percentage};
		$service_commission{value_seconds}				= $data{commission_seconds};
		$service_commission{value_number}				= $data{call_number};
		$service_commission{age_discount_id}			= $data{age_discount_id};
		$service_commission{age_discount_percentage}	= $data{age_discount_percentage};
		$service_commission{age_discount_value_before}	= $data{age_discount_value_before};
		$service_commission{age_discount_value_after}	= $data{age_discount_value_after};
		%service_commission = &multilevel_commission_new_for_one_service(%service_commission);
		foreach(&log_debug_convert_hash_to_array(%service_commission))	{$data{debug} .= "SINGLE COMMISSION $_ ! ";}
		if ($service_commission{ok} eq 1) {
			$data{commission_id} 	= $service_commission{commission_id};
			$data{log_references_last_commissions} 	= $service_commission{commission_id};
			$data{log_references_last_service_id} 	= $service_commission{service_id};
		} else {
			$data{error_code} 		= "1". substr("0000".$service_commission{error_code},-4,4);
			$data{error_message}	= "Cannot apply service_commission: $service_commission{error_message}";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
	} elsif ($data{commission_type_apply_mode} eq "ZENO") {
		#
		#--------------------------------------------------------------------
		# apply_mode=ZENO
		#--------------------------------------------------------------------
		$data{zeno_value} 						= ($data{commission_value}/2);
		$data{zeno_percentage} 					= 50;
		$data{zeno_deep} 						= $data{deep};
		$data{zeno_service_id} 					= $data{service_id};
		$data{zeno_age_discount_value_before}	= ($data{age_discount_value_before}/2);
		$data{zeno_age_discount_value_after}	= ($data{age_discount_value_after}/2);
		$data{debug} .= "Apply commission in ZENO mode ! ";
		foreach $zeno_loop (1..50) {
			#
			# apply commission
			$data{debug} .= "ZENO COMMISSION $zeno_loop ----start---- ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop deep = '$data{zeno_deep}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop zeno_value = '$data{zeno_value}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop percentage = '$data{zeno_percentage}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop zenoserviceid = '$data{zeno_service_id}' ! ";
			%service_commission = ();
			$service_commission{service_id}					= $data{zeno_service_id};
			$service_commission{title}						= $data{commission_title};
			$service_commission{value}						= $data{zeno_value};
			$service_commission{type_id}					= $data{commission_type_id};
			$service_commission{engine}						= $data{commission_type_engine};
			$service_commission{apply_mode}					= $data{commission_type_apply_mode};
			$service_commission{days_to_convert_to_credit}	= $data{commission_type_days_to_convert_to_credit};
			$service_commission{days_to_convert_to_check}	= $data{commission_type_days_to_convert_to_check};
			$service_commission{deep}						= $data{zeno_deep};
			$service_commission{percentage}					= $data{zeno_percentage};
			$service_commission{from_service_id}			= $data{from_service_id};
			$service_commission{credit_id}					= $data{credit_id};
			$service_commission{calls_id}					= $data{calls_id};
			$service_commission{value_type}					= $data{commission_type_value_type};
			$service_commission{value_default}				= $data{commission_type_value};
			$service_commission{value_base}					= $data{commission_value_base};
			$service_commission{value_percentage}			= $data{commission_percentage};
			$service_commission{value_seconds}				= $data{commission_seconds};
			$service_commission{value_number}				= $data{call_number};
			$service_commission{age_discount_id}			= $data{age_discount_id};
			$service_commission{age_discount_percentage}	= $data{age_discount_percentage};
			$service_commission{age_discount_value_before}	= $data{zeno_age_discount_value_before};
			$service_commission{age_discount_value_after}	= $data{zeno_age_discount_value_after};
			%service_commission = &multilevel_commission_new_for_one_service(%service_commission);
			foreach(&log_debug_convert_hash_to_array(%service_commission))	{$data{debug} .= "ZENO COMMISSION $zeno_loop  $_ ! ";}
			if ($service_commission{ok} eq 1) {
				$data{commission_id} 	= $service_commission{commission_id};
			}
			$data{log_references_commissions_id}	.= ($service_commission{commission_id} 	ne "") ? ",commission_id=$service_commission{commission_id}" 	: "";
			$data{log_references_service_id} 		.= ($service_commission{service_id} 	ne "") ? ",service_id=$service_commission{service_id}" 			: "";
			#
			# move to parent
			$data{zeno_value} 						= $data{zeno_value}/2;
			$data{zeno_percentage} 					= $data{zeno_percentage}/2;
			$data{zeno_deep} 						= $data{zeno_deep}+1;
			$data{zeno_service_id}					= &multilevel_service_get_parent($data{zeno_service_id});
			$data{zeno_age_discount_value_before}	= ($data{zeno_age_discount_value_before}/2);
			$data{zeno_age_discount_value_after}	= ($data{zeno_age_discount_value_after}/2);
			if ($data{zeno_service_id} eq "") {
				$data{debug} .= "No more parents ! ";
				last
			}
			$data{debug} .= "Next parent id is '$data{zeno_service_id}' ! ";
		}
	} else {
		#
		#--------------------------------------------------------------------
		# oops.. no mode
		#--------------------------------------------------------------------
	}
	#
	#--------------------------------------------------------------------
	# log action 
	#--------------------------------------------------------------------
	# if ok, log based at engine (one diffrent log type for each engine)
	# if error, log commission error (maybe some things to track error)
	#--------------------------------------------------------------------
	#
	$data{ok} = 1;
	&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},ok=1,service_id=$data{service_id}$data{log_references_commissions_id}$data{log_references_service_id}",%data);
	return %data;
}
sub multilevel_commission_new_OLD(){
	local(%data) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,%service_commission,$zeno_loop);
	# 
	#--------------------------------------------------------------------
	# This funcion apply a commission to one service (and parents if neccessary), send email (TODO: we need enable email) and log action
	# We need send at least service_id (to apply commission) and commission_type_id (to get information how to apply)
	# commission_type.value_type=percentage need value_percentage_base  to calculate percentage
	# lets work...
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# start
	#--------------------------------------------------------------------
	$data{ok} 				= 0;
	$data{error_code} 		= 0;
	$data{error_message} 	= "";
	#
	#--------------------------------------------------------------------
	# get/check/verify service_id (stop if wrong)
	#--------------------------------------------------------------------
	$data{service_id} = &clean_int($data{service_id});
	if ($data{service_id} eq "") { 
		$data{error_code} 		= 101;
		$data{error_message}	= "No service_id";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
		return %data;
	}  
	%hash =	database_select_as_hash(
				&database_scape_sql(
					"select 1,1,id,name,email,age_id,age_is_manual from service where id='%d' ",
					$data{service_id}
				),
				"flag,id,name,email,age_id,age_is_manual"
			);
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $data{service_id}) ) { 
		$data{error_code} 		= 102;
		$data{error_message}	= "Bad service_id";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
		return %data;
	}  
	$data{service_name} 		= $hash{1}{name};
	$data{service_email}		= $hash{1}{email};
	$data{service_age_id}		= $hash{1}{age_id};
	$data{service_age_is_manual}= $hash{1}{age_is_manual};
	#
	#
	#--------------------------------------------------------------------
	# get/check/verify commission_type_id (stop if wrong)
	#--------------------------------------------------------------------
	if ($data{commission_type_engine} eq "MANUAL") {
		#
		#--------------------------------------------------------------------
		# manual dont check database, get all data from %data hash
		#--------------------------------------------------------------------
		#
		$data{debug} .= "MANUAL engine, lets check each fields ! ";
		$tmp1 = &clean_int($data{commission_type_days_to_convert_to_credit});
		$tmp1 = ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=99999) ) ? $tmp1 : 7;
		$data{commission_type_days_to_convert_to_credit} = $tmp1;
		$data{debug} .= "days_to_credit is now '$data{commission_type_days_to_convert_to_credit}' ! ";
		#
		$tmp1 = &clean_int($data{commission_type_days_to_convert_to_check});
		$tmp1 = ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=99999) ) ? $tmp1 : 90;
		$data{commission_type_days_to_convert_to_check} = $tmp1;
		$data{debug} .= "days_to_check is now '$data{commission_type_days_to_convert_to_check}' ! ";
		#
		$tmp1 = $data{commission_type_apply_mode};
		$tmp1 = (index("|SINGLE|ZENO|","|$tmp1|") eq -1) ? "SINGLE" : $tmp1;
		$data{commission_type_apply_mode} = $tmp1;
		$data{debug} .= "apply_mode is now '$data{commission_type_apply_mode}' ! ";
		#
		# ps: manual engine can only get value_type=value. 
		$data{commission_type_value_type} = "VALUE";
		$data{debug} .= "value_type is now 'VALUE' ! ";
		#
		$data{commission_type_value}++;
		$data{commission_type_value}--;
		$tmp1 = $data{commission_type_value};
		unless ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=100) ) {
			$data{error_code} 		= 151;
			$data{error_message}	= "Bad commission_type_value for manual engine. Valid range is 0-100";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code}",%data);
			return %data;
		}
	} else {
		#
		#--------------------------------------------------------------------
		# not manual so we need search at database (stop if wrong)
		#--------------------------------------------------------------------
		$data{commission_type_id} = &clean_int($data{commission_type_id});
		if ( ($data{commission_type_id} eq "") && ($data{commission_type_engine}) ) {
			$data{debug} .= "commission_type_id is empty but we have commission_type_engine. Lets try guess commission_type_id ! ";
			$data{commission_type_id} = &multilevel_commission_new_get_type_id_by_engine_and_service_id($data{commission_type_engine},$data{service_id});
			$data{debug} .= "found commission_type_id='$data{commission_type_id}'  ! ";
			# 
			# to avoid database overflow, lets not log commissions with no definition
			if ($data{commission_type_id} eq "") { 
				$data{debug} .= "no commission found ! ";
				$data{ok} = 1;
				&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},service_id=$data{service_id}",%data);
				return %data;
			}
		}
		if ($data{commission_type_id} eq "") { 
			$data{error_code} 		= 111;
			$data{error_message}	= "No commission_type_id";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}  
		%hash =	database_select_as_hash(
					&database_scape_sql(
					"SELECT 1,1,id,engine,title,value,value_type,apply_mode,days_to_convert_to_credit,days_to_convert_to_check FROM service_commission_type where id='%d' ",
					$data{commission_type_id}
					),
					"flag,id,engine,title,value,value_type,apply_mode,days_to_convert_to_credit,days_to_convert_to_check"
				);
		unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $data{commission_type_id}) ) { 
			$data{error_code} 		= 112;
			$data{error_message}	= "Bad commission_type_id";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}  
		$data{commission_type_engine}						= $hash{1}{engine};
		$data{commission_type_value_search_phone_table}		= ( index("|REFERRAL_FIRST_CALL|REFERRAL_DIALOUT_DST|REFERRAL_DIALOUT_DID|SERVICE_FIRST_CALL|SERVICE_DIALOUT_DST|SERVICE_DIALOUT_DID|SERVICE_RADIO_DID|","|$data{commission_type_engine}|") eq -1 ) ? 0 : 1;
		$data{commission_type_days_to_convert_to_credit} 	= $hash{1}{days_to_convert_to_credit}; 
		$data{commission_type_days_to_convert_to_check}		= $hash{1}{days_to_convert_to_check}; 
		$data{commission_type_apply_mode}					= $hash{1}{apply_mode};
		$data{commission_type_value}						= $hash{1}{value};
		$data{commission_type_value_type}					= $hash{1}{value_type};		
	}
	#
	#--------------------------------------------------------------------
	# check extra fields (we need stop if wrong)
	#--------------------------------------------------------------------
	if ($data{commission_type_value_type} eq "PERCENTAGE") {
		if ($data{value_percentage_base} eq "") {
			$data{error_code} 		= 201;
			$data{error_message}	= "commission_type_value_type is PERCENTAGE but no value_percentage_base ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
		$data{value_percentage_base}++;
		$data{value_percentage_base}--;
		if ( ($data{value_percentage_base} < 0) || ($data{value_percentage_base} > 1000) ) {
			$data{error_code} 		= 202;
			$data{error_message}	= "invalid value_percentage_base (valid range 0-1000)";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
	}
	if ($data{commission_type_value_type} eq "PER_MINUTE") {
		if ($data{call_seconds} eq "") {
			$data{error_code} 		= 203;
			$data{error_message}	= "commission_type_value_type is PER_MINUTE but no call_seconds ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
		$data{call_seconds}++;
		$data{call_seconds}--;
		if ( ($data{call_seconds} < 0) || ($data{call_seconds} > (60*60*12) ) ) {
			$data{error_code} 		= 204;
			$data{error_message}	= "invalid call_seconds. valid range 0 to (60*60*12) ";
			&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
			return %data;
		}
	}
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# clean some basic variables (we dont need stop if wrong, just fix)
	#--------------------------------------------------------------------
	$tmp1 = &clean_int($data{deep});
	$data{deep} = ( ($data{deep} ne "") && ($data{deep}>=0) && ($data{deep}<=99999) ) ? $data{deep} : 1;
	#if ($data{commission_type_engine} eq "MANUAL") {
	#} else {
	#	$data{deep} = 1;
	#}
	#
	#--------------------------------------------------------------------
	# calc commission_value. 
	# 1- get default value from commission_type, 
	# 2- search specific value at phone_table if need
	# 3- transform from percentage to money value if necessary 
	# 4- transform from per_minute to money value if necessary 
	# age discount dont apply here.. age shuld be per service, at multilevel_commission_new_for_one_service
	#--------------------------------------------------------------------
	# 
	# get default commission value from commission_type
	$data{debug} .= "calc commission value ! ";
	$data{commission_value} 		= $data{commission_type_value};
	$data{commission_value_type}	= $data{commission_type_value_type};
	$data{commission_value_base} 	= $data{commission_value};
	$data{commission_percentage}	= 100;
	$data{commission_seconds}		= $data{call_seconds};
	$data{debug} .= "Default value is '$data{commission_value}' ! ";
	#
	# if commission_type_engine is SERVICE_DIALOUT_DST search commission_type_by_call_dst specific value
	if ($data{commission_type_engine} eq "SERVICE_DIALOUT_DST") { 
		$data{debug} .= "engine is SERVICE_DIALOUT_DST. Lets try to find specific value for number $data{call_number},$data{commission_type_id} ! ";
		$tmp = &multilevel_commission_new_value_by_call_number($data{call_number},$data{commission_type_id});
		if ($tmp ne "") {
			$data{debug} .= "found '$tmp' ! ";
			$data{commission_value} = $tmp;
			$data{debug} .= "New value is now '$data{commission_value}' ! ";
		} else {
			$data{debug} .= "No specific value for this number ! ";
		}
	}
	#
	# if commission_type_engine is SERVICE_DIALOUT_DID search commission_type_by_call_did specific value
	if ($data{commission_type_engine} eq "SERVICE_DIALOUT_DID") { 
		$data{debug} .= "engine is SERVICE_DIALOUT_DID. Lets try to find specific value for number $data{call_number},$data{commission_type_id} ! ";
		$tmp = &multilevel_commission_new_value_by_call_number($data{call_number},$data{commission_type_id});
		if ($tmp ne "") {
			$data{debug} .= "found '$tmp' ! ";
			$data{commission_value} = $tmp;
			$data{debug} .= "New value is now '$data{commission_value}' ! ";
		} else {
			$data{debug} .= "No specific value for this number ! ";
		}
	}
	#
	# if commission_type.value_type=percentage, use value as percentage of value_base  to find value
	if ($data{commission_type_value_type} eq "PERCENTAGE") {
		$data{debug} .= "commission_type_value_type is percentage ! ";
		$data{debug} .= "Using '$data{value_percentage_base}' to calc '$data{commission_value}' percent ! ";
		$data{commission_value_base} = $data{value_percentage_base};
		$data{commission_percentage} = $data{commission_value};
		$data{commission_value} = $data{commission_value_base}*($data{commission_value}/100);
		$data{debug} .= "New value is now '$data{commission_value}' ! ";
	}
	#
	# if commission_type.value_type=percentage, use value as percentage of value_base  to find value
	if ($data{commission_type_value_type} eq "BY_CALL_MINUTES") {
		$data{debug} .= "commission_type_value_type is per minute ! ";
		$data{debug} .= "Using '$data{commission_value}' rate per minute to calc '$data{call_seconds}' seconds value ! ";
		$data{commission_value} 	= ($data{commission_value}*($data{call_seconds}/60));
		$data{debug} .= "New value is now '$data{commission_value}' ! ";
	}
	#
	# re chech commission_value
	$data{debug} .= "Re-check commission value ! ";
	$tmp1 = $data{commission_value};
	unless ( ($tmp1 ne "") && ($tmp1>=0) && ($tmp1<=100) ) {
		$data{error_code} 		= 161;
		$data{error_message}	= "Bad commission_value. Valid range is 0-100";
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},error=$data{error_code},service_id=$data{service_id}",%data);
		return %data;
	}
	#
	$data{debug} .= "commission_value is '$data{commission_value}' ! ";
	$data{debug} .= "commission_value_type is '$data{commission_value_type}' ! ";
	$data{debug} .= "commission_value_base is '$data{commission_value_base}' ! ";
	$data{debug} .= "commission_value_percentage is '$data{commission_percentage}' ! ";
	$data{debug} .= "commission_value_default is '$data{commission_type_value}' ! ";
	$data{debug} .= "commission_call_seconds is '$data{commission_seconds}' ! ";
	$data{debug} .= "commission_call_number is '$data{call_number}' ! ";
	#--------------------------------------------------------------------
	#
	#--------------------------------------------------------------------
	# abort with ok=1 if commission value is zero (no need log debug)
	#--------------------------------------------------------------------
	if ($data{commission_value} eq 0) {
		$data{debug} .= "commission_value is zero, no commission need ! ";
		$data{ok} = 1;
		&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},service_id=$data{service_id}",%data);
		return %data;
	}
	#
	#--------------------------------------------------------------------
	# apply commission
	#--------------------------------------------------------------------
	$data{log_references_commissions_id} 	= "";
	$data{log_references_service_id} 		= "";
	if ($data{commission_type_apply_mode} eq "SINGLE") {
		#
		#--------------------------------------------------------------------
		# apply_mode=SINGLE
		#--------------------------------------------------------------------
		$data{debug} .= "Apply commission in SINGLE mode ! ";
		%service_commission = ();
		$service_commission{service_id}					= $data{service_id};
		$service_commission{title}						= $data{commission_title};
		$service_commission{value}						= $data{commission_value};
		$service_commission{type_id}					= $data{commission_type_id};
		$service_commission{engine}						= $data{commission_type_engine};
		$service_commission{apply_mode}					= $data{commission_type_apply_mode};
		$service_commission{days_to_convert_to_credit}	= $data{commission_type_days_to_convert_to_credit};
		$service_commission{days_to_convert_to_check}	= $data{commission_type_days_to_convert_to_check};
		$service_commission{deep}						= $data{deep};
		$service_commission{percentage}					= $data{percentage};
		$service_commission{from_service_id}			= $data{from_service_id};
		$service_commission{credit_id}					= $data{credit_id};
		$service_commission{calls_id}					= $data{calls_id};
		$service_commission{value_type}					= $data{commission_type_value_type};
		$service_commission{value_default}				= $data{commission_type_value};
		$service_commission{value_base}					= $data{commission_value_base};
		$service_commission{value_percentage}			= $data{commission_percentage};
		$service_commission{value_seconds}				= $data{commission_seconds};
		$service_commission{value_number}				= $data{call_number};
		%service_commission = &multilevel_commission_new_for_one_service(%service_commission);
		foreach(&log_debug_convert_hash_to_array(%service_commission))	{$data{debug} .= "SINGLE COMMISSION $_ ! ";}
		$data{log_references_commissions_id} 	= ($service_commission{commission_id} ne "") ? ",commission_id=$service_commission{commission_id}" : "";
		$data{log_references_service_id} 		= ($service_commission{service_id} ne "") ? ",service_id=$service_commission{service_id}" : "";
	} elsif ($data{commission_type_apply_mode} eq "ZENO") {
		#
		#--------------------------------------------------------------------
		# apply_mode=ZENO
		#--------------------------------------------------------------------
		$data{zeno_value} 		= ($data{commission_value}/2);
		$data{zeno_percentage} 	= 50;
		$data{zeno_deep} 		= $data{deep};
		$data{zeno_service_id} 	= $data{service_id};
		$data{debug} .= "Apply commission in ZENO mode ! ";
		foreach $zeno_loop (1..50) {
			#
			# apply commission
			$data{debug} .= "ZENO COMMISSION $zeno_loop ----start---- ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop deep = '$data{zeno_deep}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop zeno_value = '$data{zeno_value}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop percentage = '$data{zeno_percentage}' ! ";
			$data{debug} .= "ZENO COMMISSION $zeno_loop zenoserviceid = '$data{zeno_service_id}' ! ";
			%service_commission = ();
			$service_commission{service_id}					= $data{zeno_service_id};
			$service_commission{title}						= $data{commission_title};
			$service_commission{value}						= $data{zeno_value};
			$service_commission{type_id}					= $data{commission_type_id};
			$service_commission{engine}						= $data{commission_type_engine};
			$service_commission{apply_mode}					= $data{commission_type_apply_mode};
			$service_commission{days_to_convert_to_credit}	= $data{commission_type_days_to_convert_to_credit};
			$service_commission{days_to_convert_to_check}	= $data{commission_type_days_to_convert_to_check};
			$service_commission{deep}						= $data{zeno_deep};
			$service_commission{percentage}					= $data{zeno_percentage};
			$service_commission{from_service_id}			= $data{from_service_id};
			$service_commission{credit_id}					= $data{credit_id};
			$service_commission{calls_id}					= $data{calls_id};
			$service_commission{value_type}					= $data{commission_type_value_type};
			$service_commission{value_default}				= $data{commission_type_value};
			$service_commission{value_base}					= $data{commission_value_base};
			$service_commission{value_percentage}			= $data{commission_percentage};
			$service_commission{value_seconds}				= $data{commission_seconds};
			$service_commission{value_number}				= $data{call_number};
			%service_commission = &multilevel_commission_new_for_one_service(%service_commission);
			foreach(&log_debug_convert_hash_to_array(%service_commission))	{$data{debug} .= "ZENO COMMISSION $zeno_loop  $_ ! ";}
			$data{log_references_commissions_id}	.= ($service_commission{commission_id} 	ne "") ? ",commission_id=$service_commission{commission_id}" 	: "";
			$data{log_references_service_id} 		.= ($service_commission{service_id} 	ne "") ? ",service_id=$service_commission{service_id}" 			: "";
			#
			# move to parent
			$data{zeno_value} 		= $data{zeno_value}/2;
			$data{zeno_percentage} 	= $data{zeno_percentage}/2;
			$data{zeno_deep} 		= $data{zeno_deep}+1;
			$data{zeno_service_id}	= &multilevel_service_get_parent($data{zeno_service_id});
			if ($data{zeno_service_id} eq "") {
				$data{debug} .= "No more parents ! ";
				last
			}
			$data{debug} .= "Next parent id is '$data{zeno_service_id}' ! ";
		}
	} else {
		#
		#--------------------------------------------------------------------
		# oops.. no mode
		#--------------------------------------------------------------------
	}
	#
	#--------------------------------------------------------------------
	# log action 
	#--------------------------------------------------------------------
	# if ok, log based at engine (one diffrent log type for each engine)
	# if error, log commission error (maybe some things to track error)
	#--------------------------------------------------------------------
	#
	$data{ok} = 1;
	&log_debug_add("type=commission_add,commission_engine=$data{commission_type_engine},ok=1,service_id=$data{service_id}$data{log_references_commissions_id}$data{log_references_service_id}",%data);
	return %data;
}
sub multilevel_commission_new_for_one_service(){
	local(%data) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql);
	#
	#--------------------------------------------------------------------
	# start
	#--------------------------------------------------------------------
	$data{ok} 				= 0;
	$data{error_code} 		= 0;
	$data{error_message} 	= "";
	#
	#--------------------------------------------------------------------
	# check some data
	#--------------------------------------------------------------------
	if ($data{service_id} eq "") {
		$data{error_code} = 201; $data{error_message} = "Bad service_id"; return %data;
	}
	$data{value}++;
	$data{value}--;
	if ( ($data{value}<0) || ($data{value}>1000) ) {
		$data{error_code} = 201; $data{error_message} = "Bad value"; return %data;
	}
	if ( ($data{type_id} ne "") && (&clean_int($data{type_id}) ne $data{type_id}) ) {
		$data{error_code} = 203; $data{error_message} = "Bad type_id"; return %data;
	}
	if (index("|MANUAL|REFERRAL_SIGNIN|REFERRAL_FIRST_CALL|REFERRAL_RECHARGE|SERVICE_DIALOUT_DID|SERVICE_DIALOUT_DST|REFERRAL_DIALOUT_DID|REFERRAL_DIALOUT_DST|RADIO_LISTEN|RADIO_OWNER|","|$data{engine}|") eq -1) {
		$data{error_code} = 204; $data{error_message} = "Bad engine"; return %data;
	}
	if (index("|SINGLE|ZENO|","|$data{apply_mode}|") eq -1) {
		$data{error_code} = 205; $data{error_message} = "Bad apply_mode"; return %data;
	}
	#
	#--------------------------------------------------------------------
	# clean some data
	#--------------------------------------------------------------------
	$data{deep} 			= ( ($data{deep} eq "") || ($data{deep}<=0) ) ? 0 : $data{deep};
	$data{percentage} 		= ( ($data{percentage} eq "") || ($data{percentage}<0) || ($data{percentage}>100) ) ? 100 : $data{percentage};
	$tmp = $data{days_to_convert_to_credit};
	$tmp = ( ($tmp eq "") || ($tmp<0) || ($tmp>99999) ) ? 7 : $tmp;
	$data{days_to_convert_to_credit} = $tmp;
	$tmp = $data{days_to_convert_to_check};
	$tmp = ( ($tmp eq "") || ($tmp<0) || ($tmp>99999) ) ? 90 : $tmp;
	$data{days_to_convert_to_check} = $tmp;
	$data{title} = &trim(substr(&clean_str($data{title},"()[]_-;,. "),0,255));
	#
	#--------------------------------------------------------------------
	# get service_id info
	#--------------------------------------------------------------------
	$sql = &database_scape_sql(
			"
			select 1,1,service.id,service.age_id,service_status.can_collect_commission,service_status.can_collect_radio_commission
			from service,service_status
			where service.id='%d' and service.status=service_status.id 
			",
			$data{service_id}
		);
	%hash =	database_select_as_hash($sql,"flag,id,age_id,can_collect_commission,can_collect_radio_commission");
	unless ( ($hash{1}{flag} eq 1) && ($hash{1}{id} eq $data{service_id}) ) { 
		$data{error_code} 		= 101;
		$data{error_message}	= "Bad service_id";
		return %data;
	}  
	$data{service_age_id}	 				= $hash{1}{age_id};
	if (index("|RADIO_LISTEN|RADIO_OWNER|","|$data{engine}|") ne -1) {
		$data{debug} .= "Use can_collect_radio_commission to know commission anabled ! ";
		$data{service_can_collect_commission} 	= $hash{1}{can_collect_radio_commission};
	} else {
		$data{debug} .= "Use can_collect_commission to know commission anabled ! ";
		$data{service_can_collect_commission} 	= $hash{1}{can_collect_commission};
	}
	#
	#--------------------------------------------------------------------
	# check can_collect_commission
	#--------------------------------------------------------------------
	if ($data{service_can_collect_commission} ne 1) {
		$data{debug} .= "Service cannot collect commission ! ";
		$data{ok} 	= 1;
		return %data;
	}
	#
	#--------------------------------------------------------------------
	# calculate age discount
	#--------------------------------------------------------------------
	#$data{service_age_discount_percentage}	= 0;
	#$data{service_age_discount_value_before}= $data{value};
	#if ($data{type_id} ne "") {
	#	%hash =	database_select_as_hash(
	#			&database_scape_sql(
	#				"
	#				select 1,1,discount_percentage 
	#				from service_commission_type_age_discount 
	#				where service_commission_type_id='%d' and service_age_id='%d' 
	#				",
	#				$data{type_id},$data{service_age_id}
	#			),
	#			"flag,discount_percenta ge"
	#		);
	#	$data{service_age_discount_percentage} = ( ($hash{1}{flag} eq 1) && ($hash{1}{discount_percentage}>=0)&& ($hash{1}{discount_percentage}<=100) ) ? $hash{1}{discount_percentage} : 0;
	#}
	#if ($data{service_age_discount_percentage}>0){
	#	$data{debug} .= "we have discount by age ! lets apply $data{service_age_discount_percentage} percent discount at $data{value} ! ";
	#	$data{value} = $data{value} - ($data{value}*($hash{1}{discount_percentage}/100));
	#	$data{debug} .= "new value is $data{value} ! ";
	#}
	#
	#--------------------------------------------------------------------
	# apply commission
	#--------------------------------------------------------------------
	#
	# hack to know old type automatily (delete after we update all app to do not use type collumn)
	$data{old_type} = "UNKNOWN";
	$data{old_type} = ($data{engine} eq "MANUAL") 				? "MANUAL" 		: $data{old_type};
	$data{old_type} = ($data{engine} eq "REFERRAL_SIGNIN") 		? "NEWF" 		: $data{old_type};
	$data{old_type} = ($data{engine} eq "REFERRAL_FIRST_CALL") 	? "NEWFCALL"	: $data{old_type};
	$data{old_type} = ($data{engine} eq "REFERRAL_RECHARGE") 	? "CREDIT" 		: $data{old_type};
	$tmp1 = ($data{type_id} 		eq "") ? "null" : &clean_int($data{type_id});
	$tmp2 = ($data{age_discount_id} eq "") ? "null" : &clean_int($data{age_discount_id});
	$data{age_discount_percentage}		= ($data{age_discount_percentage} 	eq "") ? 0 : $data{age_discount_percentage};
	$data{age_discount_value_before}	= ($data{age_discount_value_before}	eq "") ? $data{value} : $data{age_discount_value_before};
	$data{age_discount_value_after}		= ($data{age_discount_value_after} 	eq "") ? $data{value} : $data{age_discount_value_value};
	$sql = &database_scape_sql(
			"
			insert into service_commission
			(
				creation_date, activation_date_1, activation_date_2,
				service_id,  
				percentage, value,  
				age_id, age_discount_value_before, age_discount_percentage, 
				type_id, engine, apply_mode, type, 
				value_type, value_default, value_base, value_percentage,
				value_seconds, value_number
			) values (
				now(), date_add(now(),interval %d day), date_add(now(),interval %d day), 
				'%d', 
				'%s', '%s', 
				%s, '%s', '%s',  
				%s, '%s', '%s', '%s', 
				'%s', '%s', '%s', '%s',  
				'%s', '%s' 
		    )
			",
			$data{days_to_convert_to_credit}, $data{days_to_convert_to_check}, 
			$data{service_id}, 
			$data{percentage}, $data{value}, 
			$tmp2, $data{age_discount_value_before}, $data{age_discount_percentage}, 
			$tmp1, $data{engine}, $data{apply_mode}, $data{old_type}, 
			$data{value_type}, $data{value_default}, $data{value_base}, $data{value_percentage}, 
			$data{value_seconds}, $data{value_number}
		);
	$data{commission_id} = database_do_insert($sql);
	if ($data{commission_id} eq "") {
		$data{error_code} 		= 302;
		$data{debug} 			.= "SQL ! $sql ! ";
		$data{error_message}	= "I cannot add this commission. System error";
		return %data;
	}
	#
	# add extra values
	if (&clean_int($data{from_service_id}) ne "") {
		 &database_do(&database_scape_sql("update service_commission set from_service_id='%d' where id='%d'",$data{from_service_id},$data{commission_id}));
	}
	if (&clean_int($data{credit_id}) ne "") {
		 &database_do(&database_scape_sql("update service_commission set credit_id='%d' where id='%d'",$data{credit_id},$data{commission_id}));
	}
	if (&clean_int($data{calls_id}) ne "") {
		 &database_do(&database_scape_sql("update service_commission set calls_id='%s' where id='%d'",$data{calls_id},$data{commission_id}));
	}
	if (&clean_int($data{deep}) ne "") {
		 &database_do(&database_scape_sql("update service_commission set deep='%d' where id='%d'",$data{deep},$data{commission_id}));
	}
	if ($data{commission_title} ne "") {
		 &database_do(&database_scape_sql("update service_commission set title='%s' where id='%d'",$data{commission_title},$data{commission_id}));
	}
	#
	# end
	$data{ok} = 1;
	return %data;
}
sub multilevel_commission_new_value_by_call_number() {
	($number,$commission_type_id) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql,$out,$number_length,$number_slice);
	$out = "";
	$commission_type_id	= &clean_int($commission_type_id);
	$number 			= &clean_int($number);
	$number_length 		= length($number);
	if ($number_length<1) {return $out;}
	if ($commission_type_id eq "") {return $out;}
	foreach $tmp (1..$number_length){
		$number_slice = substr($number,0,$tmp);
		$sql = "SELECT 1,1,value FROM service_commission_type_by_call_number where service_commission_type_id='$commission_type_id' and prefix = '$number_slice' ",
		#warning("$tmp - $number_slice - $sql");
		%hash =	&database_select_as_hash($sql,"flag,value");
		$out = ( ($hash{1}{flag} eq 1) && ($hash{1}{value} ne "") ) ? $hash{1}{value} : $out; 
	}
	return $out;
}
sub multilevel_commission_new_get_type_id_by_engine_and_service_id(){
	# you send commission engine and service_id, we return commission_type_id
	# Right now, we only look at commission_type table, no search at service/status data
	# in future we can have differnt type of commissions based in service/status or other settings
	# this make simple to change this policie in future without change multilevel_commission_apply logic
	local($engine,$service_id) = @_;
	local(%hash,$tmp,$tmp1,$tmp2,$sql,$out,$sql);
	%hash =	database_select_as_hash( &database_scape_sql("SELECT 1,1,id FROM service_commission_type where engine='%s' order by id limit 0,1",$engine) , "flag,id");
	$out = ( ($hash{1}{flag} eq 1) && ($hash{1}{id} ne "") ) ? $hash{1}{id} : ""; 
	return $out;
}
#
#------------------------
# pin 
#------------------------
sub multilevel_pin_generate(){
	local(@chars,$loop_count,$pin,$tmp_pin,%hash,$tmp,$tmp1,$tmp2,@lookalike,$sql);
	#
	# verifica service id
	#
	# inicia variaveis
	my @chars=('0'..'9');
	my $pin = "";
	#
	# tenta criar um pin number
	foreach $loop_count (1..8) {
		#
		# cria um pin
		$tmp_pin = "";
		foreach (1..8) {$tmp_pin .= $chars[rand @chars];}
		#
		# monta lista de pins parecidos
		@lookalike = ($tmp_pin);
		#
		# verifica se existe
		$tmp= join("','",@lookalike);
		$sql = "
		SELECT 1,1,count(*) 
		FROM service_pin 
		where ( (free = 1 and last_change > date_sub(now(),interval 60 month)) or (free = 0) ) and pin in ('$tmp')
		";
		%hash = &database_select_as_hash($sql,"flag,qtd");
		#
		# aprova
		if ( ($hash{1}{flag} eq 1) && ($hash{1}{qtd} eq 0) ){
			$pin = $tmp_pin;
			last;
		}
	}
	#
	# emite alerta
	if ($loop_count>5){
		# TODO: alerta de falta de espaco pra geracao de novos PINs
	}
	#
	# ajusta pin na database
	if ($pin ne "") {
		%hash = &database_select_as_hash("select 1,1,free from service_pin where pin='$pin' ","flag,free");
		if ($hash{1}{flag} eq 1) {
			if ($hash{1}{free} eq 1) {
				# 
				# existe e free, vamos limpar ele
				&database_do("update service_pin set last_change=now(),service_id=null,signin_id=null where pin='$pin' ");
			} else {
				#
				# existe e nao free, nao pode ser usado
				$pin = "";
			}
		} else {
			#
			# nao existe, incluir
			&database_do("insert into service_pin (pin,free,last_change) values ('$pin', '1', now()) ");
		}
	}
	#
	# retorna 
	# TODO: logar PIN criado
	return "$pin";
}
sub multilevel_pin_create(){
	local($service_id) = @_;
	#
	# verifica service id
	#
	# inicia variaveis
	my @chars=('0'..'9');
	my $in_loop = 1;
	my $fail = 1;
	my $loop = 0;
	my $pin = "";
	my $pin_exists = 0;
	my $dbg = "";
	#
	# tenta criar um pin number
	while ($in_loop eq 1){
		$pin = "";
		$pin_ok = 1;
		$pin_exists = 0;
		foreach (1..8) {$pin .= $chars[rand @chars];}
		#
		# check 1 - simple number
		#$pin_ok = (index($pin,"0") eq -1) ? 1 : $pin_ok;
		#
		# check 2 - database
		if ($pin_ok eq 1) {
			my %data = &database_select_as_hash("select 1,1,free,unix_timestamp(last_change) from service_pin where pin='$pin'","flag,free,timestamp");
			if ($data{1}{flag} eq 1) {
				$pin_exists = 1;
				$gap = time - $data{1}{timestamp};
				if ($data{1}{free} eq 1) {
					$pin_ok = ($gap > (0)) ? 1 : 0;
				} else {
					$pin_ok = 0;
				}
			} else {
				$pin_ok = 1;
			}
		}
		#
		# finish loop
		$loop++;
		$in_loop = ($loop>10) ? 0 : $in_loop;
		$in_loop = ($pin_ok eq 1) ? 0 : $in_loop;
		$pin = ($pin_ok ne 1) ? "" : $pin;
	}
	#
	# se falhou, aborta
	$fail = ($pin eq "") ? 1 : 0;
	return undef if $fail;
	#
	# se nao falhou, adiciona no banco
	if ($pin_exists eq 1) {
		&database_do("update service_pin set last_change=now(), free=0, service_id='$service_id' where pin='$pin' ");
	} else {
		&database_do("insert into service_pin (pin,free,last_change,service_id) values ('$pin', '0', now(), '$service_id' ) ");
	}
	#
	# retorna o pin just in case
	return "$pin";
}
sub multilevel_pin_delete(){
	local($pin) = @_;
	&database_do("update service_pin set last_change=now(), free=1,  service_id=null where pin='$pin' ");
}
sub multilevel_pin_password_set(){
	local($pin,$password) = @_;
	&database_do("update service_pin set password='$password' where pin='$pin' ");
}
sub multilevel_pin_password_get(){
	local($pin) = @_;
	my %data = &database_select_as_hash("select 1,1,password from service_pin where pin='$pin'","flag,password");
	return $data{1}{password};
}
#------------------------
#
#------------------------
# invite
#------------------------
sub multilevel_invite_create(){
	local($service_id) = @_;
	#
	# verifica service id
	#
	# inicia variaveis
	my @chars=('0'..'9', 'A'..'N', 'P'..'Z');
	my $in_loop = 1;
	my $fail = 1;
	my $loop = 0;
	my $invite = "";
	my $invite_exists = 0;
	my $dbg = "";
	#
	# tenta criar um invite number
	while ($in_loop eq 1){
		$invite = "";
		$invite_ok = 1;
		$invite_exists = 0;
		foreach (1..5) {$invite .= $chars[rand @chars];}
		my %data = &database_select_as_hash("select 1,1,free,unix_timestamp(last_change) from service_invite where id='$invite'","flag,free,timestamp");
		if ($data{1}{flag} eq 1) {
			$invite_exists = 1;
			$gap = time - $data{1}{timestamp};
			if ($data{1}{free} eq 1) {
				$invite_ok = ($gap > (0)) ? 1 : 0;
			} else {
				$invite_ok = 0;
			}
		} else {
			$invite_ok = 1;
		}
		#
		# finish loop
		$loop++;
		$in_loop = ($loop>10) ? 0 : $in_loop;
		$in_loop = ($invite_ok eq 1) ? 0 : $in_loop;
		$invite = ($invite_ok ne 1) ? "" : $invite;
	}
	#
	# se falhou, aborta
	$fail = ($invite eq "") ? 1 : 0;
	return undef if $fail;
	#
	# se nao falhou, adiciona no banco
	if ($invite_exists eq 1) {
		&database_do("update service_invite set last_change=now(), free=0, service_id='$service_id' where id='$invite' ");
	} else {
		&database_do("insert into service_invite (id,free,last_change,service_id) values ('$invite', '0', now(), '$service_id' ) ");
	}
	#
	# retorna o invite just in case
	return "$invite";
}
sub multilevel_invite_delete(){
	local($invite) = @_;
	&database_do("update service_invite set last_change=now(), free=1,  service_id=null where id='$invite' ");
}
#------------------------
#
#------------------------
# credit
#------------------------
sub multilevel_credit_autorecharge(){
	local($value) = @_;
	local($protected_value,$l1,$l2,$cim_pofile_id,$service_id,$xml_data,$MyData,$debug,$debug_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,$sql);
	local(%data);
	$data{service_id} = clean_int($value);
	#
	#===============================================================
	# start
	#===============================================================
	$data{status_ok} 			= 0;
	$data{status_error}			= 0;
	$data{status_message}		= "";
	$data{status_message_code}	= 0;
	$data{keep_working}			= 1;
	$data{autorecharge_enabled} = 0;
	$data{system_notification} 	= "";
	$data{debug}				= "";
	#
	#===============================================================
	# verifica service_id
	#===============================================================
	if ($data{keep_working} eq 1) {
		$data{debug} .= "Check service_id ! ";
		if ($data{service_id} eq "") {
			$data{status_message}		= "No service_id";
			$data{status_message_code}	= 10;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "error";
		} else {
			$sql = "
			select
				1,1,service.balance, service.limit,
				service.name,service.email, service_status.can_auto_recharge
			from
				service, service_status
			where
				service.id = '$data{service_id}' and
				service.status = service_status.id and
				service_status.deleted = 0
			";
			%hash = database_select_as_hash($sql,"flag,balance,limit,name,email,can_auto_recharge");
			if ($hash{1}{flag} eq 1) {
				$data{service_balance}			= $hash{1}{balance}-$hash{1}{limit};
				$data{service_name}				= $hash{1}{name};
				$data{service_email}			= $hash{1}{email};
				$data{service_can_auto_recharge}= $hash{1}{can_auto_recharge};
			} else {
				$data{status_message}		= "service_id not found";
				$data{status_message_code}	= 20;
				$data{keep_working}			= 0;
				$data{system_notification} 	= "error";
			}
		}
	}
	#
	#===============================================================
	# first time detect
	#===============================================================
	%hash = database_select_as_hash("select 1,1,id from credit where service_id='$data{service_id}' order by date desc limit 0,1","flag,value");
	$tmp1 = ($hash{1}{flag} ne 1) ? "" : $hash{1}{value};
	$tmp2 = &data_get("service_data",$data{service_id},"last_recharge_id");
	$tmp1 = ($tmp1 eq "") ? 0 : $tmp1;
	$data{is_first_time} 	= ($tmp1 ne $tmp2) ? 1 : 0;
	$data{resset_first_time}= 0;
	$data{first_time_value}	= $tmp1;
	$data{debug} .= "first time detect flag=$data{is_first_time} ($tmp1,$tmp2) resset=$data{resset_first_time} value=$data{first_time_value}! ";
	#
	#===============================================================
	# verifica auto recharge
	#===============================================================
	if ($data{keep_working} eq 1) {
		$data{debug} .= "check auto recharge ! ";
		if ($data{service_can_auto_recharge} eq 1) {
			$sql = "
			select
				1,1,
				service_profile_cc.CIM_customerProfileId,
				service_profile_cc.CIM_customerPaymentProfileId
			from
				service_profile_cc
			where
				service_profile_cc.service_id = '$data{service_id}' and
				service_profile_cc.active = 1 and
				service_profile_cc.is_auto_recharge = 1
			";
			%hash = database_select_as_hash($sql,"flag,CIM_customerProfileId,CIM_customerPaymentProfileId");
			if ($hash{1}{flag} eq 1) {
				$data{service_CIM_customerProfileId}		= $hash{1}{CIM_customerProfileId};
				$data{service_CIM_customerPaymentProfileId}	= $hash{1}{CIM_customerPaymentProfileId};
				$data{autorecharge_enabled} = 1;
			} else {
				$data{status_message}		= "disabled by user";
				$data{status_message_code}	= 40;
				$data{keep_working}			= 0;
				$data{debug} .= "disabled and balance=$data{service_balance} ! ";
				if ($data{service_balance} < 2) {
					$data{status_message}		= "disabled by user with low balance";
					$data{status_message_code}	= 50;
					$data{system_notification} 	= "disabled";
				}
			}
		} else {
			$data{status_message}		= "disabled by status";
			$data{status_message_code}	= 30;
			$data{keep_working}			= 0;
		}
	}
	#
	#===============================================================
	# pega dados da auo recaga
	#===============================================================
	if ($data{keep_working} eq 1) {
		$data{debug} .= "load auto recharge ! ";
		# load
		$data{autorecharge_threshold}		= &data_get("service_data",$data{service_id},"ar_threshold");
		$data{autorecharge_threshold_value}	= (split(/\_/,$data{autorecharge_threshold}))[1];
		$data{autorecharge_threshold_type}	= (split(/\_/,$data{autorecharge_threshold}))[0];
		$data{autorecharge_value}			= &data_get("service_data",$data{service_id},"ar_value");
		$data{autorecharge_limit}			= &data_get("service_data",$data{service_id},"ar_limit");
		$data{autorecharge_limit_value}		= (split(/\_/,$data{autorecharge_limit}))[1];
		$data{autorecharge_limit_type}		= (split(/\_/,$data{autorecharge_limit}))[0];
		# check defaults
		$data{autorecharge_value}			= ($data{autorecharge_threshold_type}.$data{autorecharge_limit_type}	eq "") ? 20 		: $data{autorecharge_value};
		$data{autorecharge_threshold_value}	= (index("|balance|minutes|","|$data{autorecharge_threshold_type}|")	eq -1) ? 5 			: $data{autorecharge_threshold_value};
		$data{autorecharge_threshold_type}	= (index("|balance|minutes|","|$data{autorecharge_threshold_type}|")	eq -1) ? "balance"	: $data{autorecharge_threshold_type};
		$data{autorecharge_limit_value}		= (index("|30days|7days|","|$data{autorecharge_limit_type}|") 			eq -1) ? 60 		: $data{autorecharge_limit_value};
		$data{autorecharge_limit_type}		= (index("|30days|7days|","|$data{autorecharge_limit_type}|") 			eq -1) ? "30days" 	: $data{autorecharge_limit_type};
		# debug
		$data{debug} .= "autorecharge threshold ($data{autorecharge_threshold}) = ($data{autorecharge_threshold_type}) ($data{autorecharge_threshold_value}) ! ";
		$data{debug} .= "autorecharge limit ($data{autorecharge_limit}) = ($data{autorecharge_limit_type}) ($data{autorecharge_limit_value}) ! ";
		$data{debug} .= "autorecharge value ($data{autorecharge_value}) ! ";
		# reject wrong values
		$data{autorecharge_value}++;
		$data{autorecharge_value}--;
		if ( ($data{autorecharge_value} <= 0) || ($data{autorecharge_value} > 100) ) {
			$data{status_error}			= 1;
			$data{status_message}		= "bad auto recharge data";
			$data{status_message_code}	= 60;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "error";
		}
	}
	#
	#===============================================================
	# verifica limites da auto recarga
	#===============================================================
	if ($data{keep_working} eq 1) {
		$data{debug} .= "check auto-recharge threshold ! ";
		$tmp1 = 0;
		if ($data{autorecharge_threshold_type} eq "balance") {
			#-----------------------------
			# check threshold by balance
			#-----------------------------
			if ($data{service_balance} <= $data{autorecharge_threshold_value}) {
				$tmp1 = 1;
			} else {
				$data{status_message}		= "recharge not need. balance in threshold limit.";
				$data{status_message_code}	= 70;
				$data{keep_working}			= 0;
			}
			$data{debug} .= "... by balance threshold (balance=$data{service_balance}, threshold=$data{autorecharge_threshold_value}, tmp=$tmp1) ! ";
		} elsif ($data{autorecharge_threshold_type} eq "minutes") {
			#-----------------------------
			# check threshold by minutes
			#-----------------------------
			$data{status_error}			= 1;
			$data{status_message}		= "no threshold by minutes";
			$data{status_message_code}	= 80;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "error";
		}
		if ($tmp1 eq 1) {
			$data{debug} .= "check auto-recharge limit ! ";
			#-----------------------------
			# check recharge limit
			#-----------------------------
			$tmp2 = ($data{autorecharge_limit_type} eq "7days") ? 7 : 30;
			$sql = "
			SELECT 1,1,sum(value)
			FROM credit
			where service_id='$data{service_id}' and date>date_sub(now(), interval $tmp2 day) and value>0
			";
			%hash = database_select_as_hash($sql,"flag,value");
			$data{recharges_in_period} = ( ($hash{1}{value} eq "") || ($hash{1}{flag} ne 1) ) ? 0: $hash{1}{value};
			$data{autorecharge_limit_days} = $tmp2;
			$data{debug} .= "limit data ($data{recharges_in_period}+$data{autorecharge_value} > $data{autorecharge_limit_value}) ! ";
			if ($data{recharges_in_period}+$data{autorecharge_value} > $data{autorecharge_limit_value}) {
				$data{status_error}			= 1;
				$data{status_message}		= "recharges limit overflow";
				$data{status_message_code}	= 90;
				$data{keep_working}			= 0;
				$data{system_notification} 	= "over_limit";
			}
		}
	}
	#
	#===============================================================
	# confere CIM
	#===============================================================
	if ($data{keep_working} eq 1) {
		# load and check CIM
		$data{debug} .= "check CIM ! ";
		%hash = &multilevel_securedata_cc_get($data{service_id},"CHECK_CIM");
		$data{cim_profile_is_ok} 					= ($hash{status_ok} eq 1) ? 1 : 0;
		$data{cim_profile_status_message}			= $hash{status_message};
		$data{cim_profile_contact_number}			= $hash{contact_number};
		$data{cim_profile_type}						= $hash{cc_type};
		$data{cim_profile_number}					= $hash{cc_number};
		$data{cim_profile_date}						= $hash{cc_date};
		$data{cim_profile_code}						= $hash{cc_code};
		$data{cim_profile_first_name}				= $hash{first_name};
		$data{cim_profile_last_name}				= $hash{last_name};
		$data{cim_profile_address}					= $hash{address};
		$data{cim_profile_country}					= $hash{country};
		$data{cim_profile_city}						= $hash{city};
		$data{cim_profile_state}					= $hash{state};
		$data{cim_profile_zip}						= $hash{zip};
		$data{cim_profile_customerProfileId}		= $hash{customerProfileId};
		$data{cim_profile_customerPaymentProfileId}	= $hash{customerPaymentProfileId};
		if ($data{cim_profile_is_ok} eq 1) {
			unless (
			($data{service_CIM_customerProfileId} eq $data{cim_profile_customerProfileId}) &&
			($data{service_CIM_customerPaymentProfileId} eq $data{cim_profile_customerPaymentProfileId}) &&
			($data{service_CIM_customerPaymentProfileId} ne "") &&
			($data{cim_profile_customerPaymentProfileId} ne "") &&
			($data{service_CIM_customerProfileId} ne "") &&
			($data{cim_profile_customerProfileId} ne "")
			) {
				$data{debug} .= "oops, error ($data{service_CIM_customerProfileId},$data{cim_profile_customerProfileId}) ! ";
				$data{status_error}			= 1;
				$data{status_message}		= "incorrect cimXdb credit card profile link.";
				$data{status_message_code}	= 101;
				$data{keep_working}			= 0;
				$data{system_notification} 	= "error";
			}
		} else {
			$data{status_error}			= 1;
			$data{status_message}		= "bad credit card profile.";
			$data{status_message_code}	= 100;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "error";
		}
	}
	#
	#===============================================================
	# auto recharge
	#===============================================================
	if ($data{keep_working} eq 1) {
		$data{debug} .= "apply auto recharge ! ";
		#
		# get recharges total before recharge
		# we need that to detect if we got switch_on_first_call
		$sql = "SELECT 1,1,sum(value) FROM credit where service_id='$data{service_id}' and value>0";
		%hash = database_select_as_hash($sql,"flag,value");
		$hash{1}{value} = ($hash{1}{value} eq "") ? 0: $hash{1}{value};
		$data{autoswitch_credits_sum} = ($hash{1}{flag} eq 1) ? $hash{1}{value} : 0;
		#
		# auto recharge
		%hash = ();
		$hash{service_id}	= $data{service_id};
		$hash{value_credit}	= $data{autorecharge_value};
		$hash{value_money}	= $data{autorecharge_value};
		$hash{type}			= "AUTHORIZE_ACIM";
		$hash{from_type}	= "WEB";
		%hash= &multilevel_credit_add(%hash);
		foreach(keys %hash) {$data{"multilevel_credit_add_".$_} = $hash{$_};}
		if ($hash{ok} ne 1)  {
			$data{status_error}			= 1;
			$data{status_message}		= "credit card proccess error.";
			$data{status_message_code}	= 110;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "error";
			$data{debug} .= "auto recharge error ! ";
			# TODO: add stop coupons here!
		} else {
			$data{status_ok}			= 1;
			$data{status_message}		= "Auto recharge done";
			$data{status_message_code}	= 1000;
			$data{keep_working}			= 0;
			$data{system_notification} 	= "ok";
			$data{debug} .= "auto recharge ok ! ";
			#
			# get active ani_check info 
			$sql ="select 1,1,service_status.need_ani_check from service,service_status where service.id='$data{service_id}' and service.status=service_status.id";
			%hash = database_select_as_hash($sql,"flag,id,name,switch_on_first_credit,need_ani_check");
			$data{autoswitch_old_need_ani_check}= $hash{1}{need_ani_check};
			#
			# first recharge 
			if (&multilevel_change_service_status_by_switch_on_data($data{service_id},"switch_on_first_credit") eq 1) {
				&action_history("status:first_recharge",('service_id'=>$data{service_id}));
			}
			#
			# autorecharge charge_ok
			&multilevel_change_service_status_by_switch_on_data($data{service_id},"switch_on_autorecharge_ok_charge");
			#
			# switch on first call/suspicious check
			#$data{debug} .= "first credit. all credits=$t{dic}{switch_on_first_credit_all_credits_sum} ! ";
			#if ($data{switch_on_first_credit_all_credits_sum} eq 0) {
			#	$sql =
			#		"select 1,1,service_status.id,service_status.name,service_status.switch_on_first_credit,service_status.need_ani_check
			#		from service,service_status
			#		where service.id='$data{service_id}' and service.status=service_status.id
			#		";
			#	%hash = database_select_as_hash($sql,"flag,id,name,switch_on_first_credit,need_ani_check");
			#	$data{debug} .= "old status id=$hash{1}{id} name=$hash{1}{name} move_to=$hash{1}{switch_on_first_credit} ! ";
			#	if ($hash{1}{flag} eq 1) {
			#		$data{switch_on_first_credit_old_status_id} 	= $hash{1}{id};
			#		$data{switch_on_first_credit_old_status_name}	= $hash{1}{name};
			#		$data{switch_on_first_credit_old_next_status_id}= $hash{1}{switch_on_first_credit};
			#		$data{switch_on_first_credit_old_need_ani_check}= $hash{1}{need_ani_check};
			#		if ($data{switch_on_first_credit_old_next_status_id} ne "") {
			#			&database_do("update service set last_change=now(), status='$data{switch_on_first_credit_old_next_status_id}' where id='$data{service_id}'");
			#			$sql = "select 1,1,service_status.id,service_status.name from service,service_status where service.id='$data{service_id}' and service.status=service_status.id";
			#			%hash = database_select_as_hash($sql,"flag,id,name");
			#			$data{debug} .= "new status id=$hash{1}{id} name=$hash{1}{name} ! ";
			#			if ($hash{1}{flag} eq 1) {
			#				$data{switch_on_first_credit_new_status_id} 	= $hash{1}{id};
			#				$data{switch_on_first_credit_new_status_name}	= $hash{1}{name};
			#			}
			#			&action_history("status:first_recharge",(
			#				'service_id'=>$data{service_id},
			#				'value_old'=>"$data{switch_on_first_credit_old_status_name}",
			#				'value_new'=>"$data{switch_on_first_credit_new_status_name}"
			#				));
			#		}
			#	}
			#}
			#
			# switch on first call/suspicious check
			if ($data{autoswitch_old_need_ani_check} eq 1) {
				$data{debug} .= "suspicious check with force_suspicious_if_no_validated_ani ! ";
				%hash = &multilevel_suspicious_check(('service_id'=>$data{service_id}, 'force_suspicious_if_no_validated_ani'=>1));
			} else {
				$data{debug} .= "suspicious check ! ";
				%hash = &multilevel_suspicious_check(('service_id'=>$data{service_id}));
			}
		}
	}
	#
	#===============================================================
	# email and log action
	#===============================================================
	if ($data{system_notification} eq "ok") {
		$data{debug} .= "Notify and log auto recharge ! ";
		# email
		%email = ();
		$email{to}									= $data{service_email};
		$email{template}							= "autorecharge.ok";
		$email{dic}{pin}							= &format_pin($hash{1}{pin});
		$email{dic}{name}							= $data{service_name};
		$email{dic}{email}							= $data{service_email};
		$email{dic}{balance}						= &format_number($data{service_balance},2);
		$email{dic}{autorecharge_value}				= &format_number($data{autorecharge_value},2);
		$email{dic}{autorecharge_threshold_value}	= &format_number($data{autorecharge_threshold_value},2);
		$email{dic}{autorecharge_limit_value}		= &format_number($data{autorecharge_limit_value},2);
		&multilevel_send_email(%email);
		&action_history("ar:ok",('service_id'=>$data{service_id}));
	} elsif ($data{system_notification} eq "over_limit") {
		if ($data{is_first_time} eq 1) {
			%email = ();
			$email{to}									= $data{service_email};
			$email{template}							= "autorecharge.overlimit";
			$email{dic}{pin}							= &format_pin($hash{1}{pin});
			$email{dic}{name}							= $data{service_name};
			$email{dic}{email}							= $data{service_email};
			$email{dic}{balance}						= &format_number($data{service_balance},2);
			$email{dic}{autorecharge_value}				= &format_number($data{autorecharge_value},2);
			$email{dic}{autorecharge_threshold_value}	= &format_number($data{autorecharge_threshold_value},2);
			$email{dic}{autorecharge_limit_value}		= &format_number($data{autorecharge_limit_value},2);
			$data{debug} .= "notify and log over_limit_action ! ";
			&multilevel_send_email(%email);
			&action_history("ar:overlimit",('service_id'=>$data{service_id}));
		} else {
			$data{debug} .= "over_limit_action already notifyed! ";
		}
		$data{resset_first_time} = 1;
	} elsif ($data{system_notification} eq "disabled") {
		if ($data{is_first_time} eq 1) {
			%email = ();
			$email{to}									= $data{service_email};
			$email{template}							= "autorecharge.disabled";
			$email{dic}{pin}							= &format_pin($hash{1}{pin});
			$email{dic}{name}							= $data{service_name};
			$email{dic}{email}							= $data{service_email};
			$email{dic}{balance}						= &format_number($data{service_balance},2);
			$email{dic}{autorecharge_threshold_value}	= &format_number(2,2);
			$data{debug} .= "notify and log over_limit_action ! ";
			&multilevel_send_email(%email);
			$data{debug} .= "notify and log disabled-action ! ";
			&action_history("ar:disabled",('service_id'=>$data{service_id}));
		} else {
			$data{debug} .= "disable_action already notifyed! ";
		}
		$data{resset_first_time} = 1;
	} elsif ($data{system_notification} eq "error") {
		$data{debug} .= "log error=$data{status_message} (cod=$data{status_message_code}) ! ";
		&action_history("ar:error",('service_id'=>$data{service_id},'value_new'=>"$data{status_message} (cod=$data{status_message_code})"));
	}
	#
	#===============================================================
	# debug log se teve erro
	#===============================================================
	if ( ($data{status_ok} eq 1) || ($data{status_error} eq 1) ) {
		$tmp = "";
		$tmp .= "\n----------------------------------------\n";
		$tmp .= "STATUS --> ".`date`;
		$tmp .= "STATUS --> service_id=$data{service_id}\n";
		$tmp .= "STATUS --> service_name=$data{service_name}\n";
		$tmp .= "STATUS --> status_message=$data{status_message} \n";
		$tmp .= "STATUS --> ok/error/msg_code/system=$data{status_ok},$data{status_error},$data{status_message_code},$data{system_notification}\n";
		foreach (split(/\!/,$data{debug})) {
			$tmp .= "DEBUG ---> $_\n";
		}
		foreach (sort keys %data) {
			if ($_ eq "debug") {next;}
			if (index($_,"card_number") ne -1) 	{$tmp .= "DATA DUMP --> $_=XXXXXXXXXXXX".substr($data{$_},-4,4)."\n"; next}
			$tmp .= "DATA DUMP --> $_=$data{$_}\n";
		}
		$tmp1 = ($data{status_ok} eq 1) ? "autorecharge.ok.log" : "autorecharge.error.log";
		open(OUTE,">>$app_root/website/log/$tmp1");
		print OUTE "$tmp\n";
		close(OUTE);
	}
	#
	#===============================================================
	# return
	#===============================================================
	if ($data{resset_first_time} eq 1) {
		&data_set("service_data",$data{service_id},"last_recharge_id",$data{first_time_value});
	}
	return %data
}
sub multilevel_credit_by_phone() {
	local($service_id,$recharge_amt) = @_;
 	local($protected_value,$l1,$l2,$cim_pofile_id,$xml_data,$MyData,$debug,$debug_id);
	local($tmp,$tmp1,$tmp2,%hash,%tmp_hash,$sql,%t,%order,%answer);
	#
	#=======================================
	# start default data into %t hash
	#=======================================
	%t = ();
	$t{service_id} 						= $service_id;
	$t{recharge_amt} 					= $recharge_amt ;
	$t{status_ok}						= 0;
    $t{status_error}					= 0;
    $t{status_error_id}					= "";
	$t{can_add_credit}					= 0;
	$t{cim_profile_is_ok}				= 0;
	$t{limit_max_balance}				= 0;
	$t{limit_max_recharges_in_7days}	= 0;
	$t{balance}							= 0;
	$t{all_credits_sum}					= 0;
	$t{switch_on_first_credit}			= "";
	#
	#=======================================
	# get service status limit/data
	#=======================================
	if ($t{status_error} eq 0) {
		$sql = "
		SELECT
			1, 1,
			service_status.can_add_credit, service_status.switch_on_first_credit, 
			service_status.limit_max_balance, service_status.limit_max_recharges_in_7days,
			service.balance, service.limit
		FROM service, service_status
		where service.status=service_status.id and service.id='$service_id'
		";
		%hash = database_select_as_hash($sql,"flag,can_add_credit,switch_on_first_credit,limit_max_balance,limit_max_recharges_in_7days,balance,limit");
		if ($hash{1}{flag} eq 1) {
			$t{can_add_credit}					= ($hash{1}{can_add_credit} eq 1) ? 1 : 0;
			$t{limit_max_balance}				= $hash{1}{limit_max_balance};
			$t{limit_max_recharges_in_7days}	= $hash{1}{limit_max_recharges_in_7days};
			$t{balance}							= $hash{1}{balance}-$hash{1}{limit};
			$t{switch_on_first_credit}			= $hash{1}{switch_on_first_credit};
		} else {
			$t{status_error} 	= 1;
			$t{status_error_id} = "ServiceStatusNotFound";
		}
	}
	#
	#=======================================
	# get recharges in last 7 days
	#=======================================
	if ($t{status_error} eq 0) {
		$sql = "
		SELECT 1,1,sum(value)
		FROM credit 
		where service_id='$service_id' and date>date_sub(now(), interval 7 day) and value>0
		";
		%hash = database_select_as_hash($sql,"flag,value");
		$hash{1}{value} = ($hash{1}{value} eq "") ? 0: $hash{1}{value}; 
		$t{recharges_in_7_days} = ($hash{1}{flag} eq 1) ? $hash{1}{value} : 0; 
	}
	#
	#=======================================
	# get all credits sum (why?)
	#=======================================
	if ($t{status_error} eq 0) {
		$sql = "
		SELECT 1,1,sum(value)
		FROM credit 
		where service_id='$service_id' and value>0
		";
		%hash = database_select_as_hash($sql,"flag,value");
		$hash{1}{value} = ($hash{1}{value} eq "") ? 0: $hash{1}{value}; 
		$t{all_credits_sum} = ($hash{1}{flag} eq 1) ? $hash{1}{value} : 0; 
	}
	#
	#=======================================
	# check CIM profile
	#=======================================
	if ($t{status_error} eq 0) {
		%tmp_hash = &multilevel_securedata_cc_get($service_id);
		$t{cim_profile_is_ok} 	= ($tmp_hash{status_ok} eq 1) ? 1 : 0;
		$t{cc_contact_number}	= $tmp_hash{contact_number};
		$t{cc_type}				= $tmp_hash{cc_type};
		$t{cc_number}			= $tmp_hash{cc_number};
		$t{cc_date}				= $tmp_hash{cc_date};
		$t{cc_code}				= $tmp_hash{cc_code};
		$t{cc_first_name}		= $tmp_hash{first_name};
		$t{cc_last_name}		= $tmp_hash{last_name};
		$t{cc_address}			= $tmp_hash{address};
		$t{cc_country}			= $tmp_hash{country};
		$t{cc_city}				= $tmp_hash{city};
		$t{cc_state}			= $tmp_hash{state};
		$t{cc_zip}				= $tmp_hash{zip};
		if ($t{cim_profile_is_ok} ne 1) {
			$t{status_error} 	= 1;
			$t{status_error_id} = "ServiceCIMProfileError";
		}
	}
    #
	#=======================================
	# second check recharge value
	#=======================================
	if ($t{status_error} eq 0) {
		if ($t{can_add_credit} eq 1) {
			if ( ($t{limit_max_recharges_in_7days} > 0) && ($t{recharges_in_7_days} > $t{limit_max_recharges_in_7days}) ) {
				$t{status_error} 	= 1;
				$t{status_error_id} = "LimitMaxRechargesIn7Days";
			} else {
				if ( ($t{limit_max_balance} > 0) && ($t{balance}+ $recharge_amt  > $t{limit_max_balance}) ) {
					$t{status_error} 	= 1;
					$t{status_error_id} = "LimitMaxBalance";
				}
			}
		} else {
			$t{status_error} 	= 1;
			$t{status_error_id} = "ServiceCannotAddCredit";
		}
	}
    #
	#=======================================
    # add charge
	#=======================================
	if ($t{status_error} eq 0) {
		#
		# prepare order
		%order = ();
		$order{service_id}			= $service_id;
		$order{value_credit}		= $recharge_amt;
		$order{value_money}			= $recharge_amt;
		$order{type}				= "AUTHORIZE_PCIM";
		$order{from_type}			= "PHONE";
		$order{text}				= "";
		#
		# apply order
		%answer = &multilevel_credit_add(%order);
		$t{credit_add_message}	= $order{message};
		$t{credit_add_ok} 		= $order{ok};
		$t{new_credit_id}		= $order{new_credit_id};
		#
		# check order
		if ($answer{ok} ne 1)  {
			#
			# order error
			$t{status_error} 	= 1;
			$t{status_error_id} = "MultilevelCreditAddFail";
		} else {
			#
			# order ok
			$t{status_ok} = 1;
			#
			# check switch_on_first_credit
			if ( ($t{all_credits_sum} eq 0)  && ($t{switch_on_first_credit} ne "") ) {
				&multilevel_change_service_status_by_switch_on_data($service_id,"switch_on_first_credit");
				&action_history("status:first_recharge",('service_id'=>$service_id));
				&multilevel_suspicious_check(('service_id'=>$service_id, 'force_suspicious_if_no_validated_ani'=>1)); # NOTE: why suspicious_check here?? do we need?
			} else {
				&multilevel_suspicious_check(('service_id'=>$service_id)); # NOTE: why suspicious_checkhere?? do we need?
			}
		}
	} 
	#
	#=======================================
	# return
	#=======================================
	return %t ;
}
sub multilevel_credit_undel(){
	my (%order) = @_;
	my (%credit_data);
	my (@names,@values,$i,$count,@l,%data,%hash,$sql,$tmp,$tmp1,$tmp2);
	#
	#--------------------------------------
	# cria valores default
	#--------------------------------------
	$order{message}	= "";
	$order{ok}		= 0;
	$order{debug} 	.= "START: now debug belong to credit_add function ! ";
	#
	#--------------------------------------
	# confere credit
	#--------------------------------------
	%hash = &database_select_as_hash("
	SELECT 1,1,unix_timestamp(date),service_id,status,credit_type,credit,value,text
	FROM credit
	where id='$order{credit_id}'
	","flag,date_timestamp,service_id,status,credit_type,credit,value,text"
	);
	if ($hash{1}{flag} ne 1) {$order{message}="Unknown credit_id"; return %order}
	if ($hash{1}{service_id} eq "") {$order{message}="Unknown service_id"; return %order}
	%credit_data = %{$hash{1}};
	#
	#--------------------------------------
	# confere credit type
	#--------------------------------------
	#if (index("\U|free|","\U|$credit_data{credit_type}|") eq -1) {
	#	$order{message}	 = "I cannot delete credit type '$credit_data{credit_type}'";
	#	return %order;
	#}
	#
	#--------------------------------------
	# confere status
	#--------------------------------------
	if ($credit_data{status} ne -1) {
		$order{message}	 = "I cannot delete. Credit already deleted.";
		return %order;
	}
	#
	#--------------------------------------
	# delete FREE
	#--------------------------------------
	#if ( "\Ufree" eq "\U$credit_data{credit_type}") {
		&database_do("update credit set status=1 where id='$order{credit_id}' ");
		&database_do("update service set balance = balance + $credit_data{credit} where id = '$credit_data{service_id}' ");
		&database_do("update service_commission set status=1 where credit_id = '$order{credit_id}' ");
		$order{message}	= "Deleted!";
		$order{ok}		= 1;
		return %order;
	#}
	#
	#--------------------------------------
	# return
	#--------------------------------------
	return %order;
}
sub multilevel_credit_del(){
	my (%order) = @_;
	my (%credit_data);
	my (@names,@values,$i,$count,@l,%data,%hash,$sql,$tmp,$tmp1,$tmp2);
	#
	#--------------------------------------
	# cria valores default
	#--------------------------------------
	$order{message}	= "";
	$order{ok}		= 0;
	$order{debug} 	.= "START: now debug belong to credit_add function ! ";
	#
	#--------------------------------------
	# confere credit
	#--------------------------------------
	%hash = &database_select_as_hash("
	SELECT 1,1,unix_timestamp(date),service_id,status,credit_type,credit,value,text
	FROM credit
	where id='$order{credit_id}'
	","flag,date_timestamp,service_id,status,credit_type,credit,value,text"
	);
	if ($hash{1}{flag} ne 1) {$order{message}="Unknown credit_id"; return %order}
	if ($hash{1}{service_id} eq "") {$order{message}="Unknown service_id"; return %order}
	%credit_data = %{$hash{1}};
	#
	#--------------------------------------
	# confere credit type
	#--------------------------------------
	#if (index("\U|free|","\U|$credit_data{credit_type}|") eq -1) {
	#	$order{message}	 = "I cannot delete credit type '$credit_data{credit_type}'";
	#	return %order;
	#}
	#
	#--------------------------------------
	# confere status
	#--------------------------------------
	if ($credit_data{status} ne 1) {
		$order{message}	 = "I cannot delete. Credit already deleted.";
		return %order;
	}
	#
	#--------------------------------------
	# delete FREE
	#--------------------------------------
	#if ( "\Ufree" eq "\U$credit_data{credit_type}") {
		&database_do("update credit set status=-1 where id='$order{credit_id}' ");
		&database_do("update service set balance = balance - $credit_data{credit} where id = '$credit_data{service_id}' ");
		&database_do("update service_commission set status=-1 where credit_id = '$order{credit_id}' ");
		$order{message}	= "Deleted!";
		$order{ok}		= 1;
		return %order;
	#}
	#
	#--------------------------------------
	# return
	#--------------------------------------
	return %order;
}
sub multilevel_credit_add(){
	my (%order) = @_;
	my (%authorize_answer,$sql,%account_data,%agent_data);
	my (@names,@values,$i,$count,@l,%data,%hash,%service_data,%CIM_data);
	my ($tmp,$tmp1,$tmp2);
	$app{authorize_api_login_id}		= &data_get("system_config","authorize","login_id");
	$app{authorize_api_tran_key}		= &data_get("system_config","authorize","tran_key");
	$app{authorize_api_is_test}			= &data_get("system_config","authorize","is_test");
	$app{default_commission_base} 		= &data_get("system_config","commission","credit_percentage");
	$app{default_commission_mode} 		= &data_get("system_config","commission","credit_mode");
	#
	#--------------------------------------
	# start default
	#--------------------------------------
	%authorize_answer = ();
	$order{message}	= "";
	$order{ok}	= 0;
	$order{debug} .= "START: now debug belong to credit_add function ! ";
	$order{credit_authorize_detail_id}	= "";
	#
	#--------------------------------------
	# Check basic to do
	#--------------------------------------
	if ($order{message} eq "") {
		if (&form_check_integer	($order{service_id})			ne 1)	{$order{message}="Wrong service";					}
		if (&form_check_float	($order{value_credit})			ne 1)	{$order{message}="Wrong credit on account value";	}
		if (&form_check_float	($order{value_money})			ne 1)	{$order{message}="Wrong money value";				}
		if (&form_check_string	($order{type})					ne 1)	{$order{message}="Wrong credit type ($order{type}) (".&form_check_string($order{type}).")";				}
		if (&form_check_string	($order{text},"allow_blank")	ne 1)	{$order{message}="Wrong text";						}
		$order{debug} .= "data check 1 ! ";
		$order{type} = "\U$order{type}";
		if (index("|FREE|AUTHORIZE_CC|AUTHORIZE_CIM|AUTHORIZE_ACIM|AUTHORIZE_PCIM|COMMISSION_CRED|CASH|","|$order{type}|") eq -1) { $order{message} = "Unknown credit type"; }
	}
	#
	#--------------------------------------
	# check service/acc/product/type at db
	#--------------------------------------
	%service_data = ();
	$service_data{found} = 0;
	if ($order{message} eq "") {
		$sql = "
		select 1,1,
			service.id, service.balance, service.limit,
			product.id, product_type.id
		from
			service, service_status, product, product_type
		where
			service.id = '$order{service_id}' and
			service.status = service_status.id and
			service_status.deleted = 0 and
			service.product_id = product.id and
			product.product_type = product_type.id
		";
		%tmp = database_select_as_hash($sql,"flag,service_id,service_balance,service_limit,product_id,product_type_id");
		if ($tmp{1}{flag} eq 1) {
			%service_data = %{$tmp{1}};
			$service_data{found} = 1;
			$service_data{commission_base} = $app{default_commission_base};
			$order{debug} .= "service and product ok ! ";
		} else {
			$order{message}="Wrong service";
			$order{debug} .= "Wrong service ! ";
		}
	}
	$order{debug} .= "service/acc/product/type ! ";
	#
	#--------------------------------------
	# check type and pre-check some things
	#--------------------------------------
	if ($order{message} eq "") {
		#
		$order{debug} .= "check credit type ! ";
		if ($order{type} eq "FREE") {
			# free: check if no money value
			$order{debug} .= "FREE credit detect ! ";
			if ($order{value_money} 	ne 0)		{$order{message}="Free credit does not accept money";	}
			if ($order{value_credit}	<  -100)	{$order{message}="Free credit limit is -100 to 100";	}
			if ($order{value_credit}	>  100)		{$order{message}="Free credit limit is -100 to 100";	}
			#
			#
		} elsif ($order{type} eq "CASH") {
			# cash: check limit
			$order{debug} .= "CASH credit detect ! ";
			if ($order{value_money}	<= 0)						{$order{message}="Cash credit limit is >0 to 100";	}
			if ($order{value_money}	>  100)						{$order{message}="Cash credit limit is >0 to 100";	}
			if ($order{value_credit} ne $order{value_money})	{$order{message}="Cash credit incorrect money/credit values";	}
			#
			#
		} elsif ($order{type} eq "AUTHORIZE_CC") {
			# do basic check at authorize data
			# only check, no action 
			$order{debug} .= "AUTHORIZE credit detect ! ";
			#$order{debug} .= "AUTHORIZE ids ($app{authorize_api_is_test} - $app{authorize_api_login_id} - $app{authorize_api_tran_key}) ! ";
			if ($order{value_credit}	< 0)						{$order{message}="Wrong credit value";	}
			if ($order{value_money}		< 0)						{$order{message}="Wrong money value";				}
			if ($order{value_money} ne $order{value_credit}) 		{$order{message}="Diferent money and credit values for authorize credit";	}
			if (&form_check_integer	($order{card_number}) ne 1) 	{$order{message}="Wrong card number for authorize credit";			 	}
			$order{card_date} = &clean_int($order{card_date});
			$tmp1 = substr($order{card_date},0,2); $tmp1++;$tmp1--;
			$tmp2 = substr($order{card_date},2,2); $tmp2++;$tmp2--;
			unless (
				(length($order{card_date}) eq 4) &&
				($tmp1 >= 1) &&
				($tmp1 <= 12) &&
				($tmp2 >= 0) &&
				($tmp2 <= 99)
				) {
				$order{message}="Wrong card date for authorize credit";
			}
			#
			#
		} elsif ( ($order{type} eq "AUTHORIZE_CIM") || ($order{type} eq "AUTHORIZE_ACIM") || ($order{type} eq "AUTHORIZE_PCIM") )  {
			# do basic check at authorize data
			# only check, no action 
			$order{debug} .= "AUTHORIZE CIM credit detect ! ";
			#$order{debug} .= "AUTHORIZE ids ($app{authorize_api_is_test} - $app{authorize_api_login_id} - $app{authorize_api_tran_key}) ! ";
			if ($order{value_credit}	< 0)						{$order{message}="Wrong credit value";	}
			if ($order{value_money}		< 0)						{$order{message}="Wrong money value";				}
			if ($order{value_money} ne $order{value_credit}) 		{$order{message}="Diferent money and credit values for authorize credit";	}
			%CIM_data = &multilevel_securedata_cc_get($order{service_id});
			unless ($CIM_data{status_ok} eq 1) 						{$order{message}="No CIM payment profile";}
			#
		} elsif ($order{type} eq "COMMISSION_CRED") {
			$order{debug} .= "COMMISSION credit detect! ";
			#
			# check basic only
			$order{debug} .= "COMMISSION check values! ";
			if ($order{value_money} 	ne 0)	{$order{message}="Commission credit does not accept money";	}
			if ($order{value_credit}	<= 0)	{$order{message}="Wrong credit value";	}
			#
			# check if comission_ids are ok and if this sum is the same as money_value
			$order{debug} .= "COMMISSION check ids and values ($order{commissions_ids})! ";
			@ids_array = split(/\,/,$order{commissions_ids});
			$ids_brute = "";
			$ids_qtd = 0;
			foreach (@ids_array) {
				$tmp = clean_int($_);
				if ($tmp eq "") {next}
				if ($_ ne $tmp) {next}
				$ids_brute .= "$_,";
				$ids_qtd++;
			}
			if ($ids_qtd eq 0){
				$order{message}="No commissions to invoice";
			} else {
				$ids_brute = substr($ids_brute,0,-1);
				%hash = database_select_as_hash("SELECT 1,1,count(*),sum(value) FROM service_commission WHERE status=1 and service_id='$order{service_id}' and invoice_id is null and id in ($ids_brute)","flag,qtd,value");
				if ($hash{1}{flag} eq 1) {
					if ($hash{1}{qtd} ne $ids_qtd) {
						$order{debug} .= "COMMISSION problem in commissions count (".$hash{1}{qtd}.")=(".$ids_qtd.")=(".$ids_brute.")! ";
						$order{message}="Incorrect commissions quantity to invoice";
					#} elsif (&format_number($hash{1}{value},2) ne &format_number($order{value_credit},2)) {
					#} elsif ( ($hash{1}{value}>($order{value_credit}+0.5)) || ($hash{1}{value}<($order{value_credit}-0.5))  ) {
					#	$order{debug} .= "COMMISSION problem in values sum (".$hash{1}{value}.")=(".$order{value_credit}.")! ";
					#	$order{message}="Incorrect commissions quantity to invoice";
					} else {
						# all ok with commissions list
						$order{debug} .= "COMMISSION ids and values are OK! ";
						$order{commissions_ids} = $ids_brute;
					}
				} else {
					$order{message}="Incorrect commissions to invoice";
				}
			}
		} else {
			# unknown credit type. error
			$order{message} = "Unknown credit type";
			#
		}
	}
	#
	#--------------------------------------
	# Check source
	#--------------------------------------
	$order{source_type}	= "\U$order{source_type}";
	$order{source_type} = ($order{source_type} eq "") ? "WEB" : $order{source_type};
	$order{extra}		= "refer=$ENV{HTTP_REFERER}&uri=$ENV{REQUEST_URI}&ip=$ENV{REMOTE_ADDR}&useragent=$ENV{HTTP_USER_AGENT}&timestamp=".time."&active_user_id=";
	#
	#--------------------------------------
	# AUTHORIZE_CIM  step 1
	# check CIM profile at authorize and collect money
	#--------------------------------------
	if ( ($order{message} eq "") && ( ("\U$order{type}" eq "AUTHORIZE_CIM") || ("\U$order{type}" eq "AUTHORIZE_ACIM")  || ("\U$order{type}" eq "AUTHORIZE_PCIM") ) ){
		#
		# get cc_profile at authorize CIM.
		$order{debug} .= "get CIM payment profile for service_id=$order{service_id}! ";
		%tmp_hash = &multilevel_securedata_cc_get($order{service_id},"CHECK_CIM");
		$order{cim_profile_is_ok} 			= ($tmp_hash{status_ok} eq 1) ? 1 : 0;
		$order{cim_profile_cc_id} 			= $tmp_hash{cc_id};
		$order{cim_profile_status_message}	= $tmp_hash{status_message};
		$order{cim_profile_contact_number}	= $tmp_hash{contact_number};
		$order{cim_profile_type}			= $tmp_hash{cc_type};
		$order{cim_profile_number}			= $tmp_hash{cc_number};
		$order{cim_profile_date}			= $tmp_hash{cc_date};
		$order{cim_profile_code}			= $tmp_hash{cc_code};
		$order{cim_profile_first_name}		= $tmp_hash{first_name};
		$order{cim_profile_last_name}		= $tmp_hash{last_name};
		$order{cim_profile_address}			= $tmp_hash{address};
		$order{cim_profile_country}			= $tmp_hash{country};
		$order{cim_profile_city}			= $tmp_hash{city};
		$order{cim_profile_state}			= $tmp_hash{state};
		$order{cim_profile_zip}				= $tmp_hash{zip};
		$order{customerProfileId}			= $tmp_hash{customerProfileId};
		$order{customerPaymentProfileId}	= $tmp_hash{customerPaymentProfileId};
		#
		# check CC_profile
		if ($order{cim_profile_is_ok} eq 1) {
			$order{debug} .= "get CIM payment profile ok! ";
			#
			# if CIM profile is ok, try collect money
			#AUTH_CAPTURE
			$tmp1 = $order{value_money};
			$tmp2 = "<cardCode>000</cardCode>";
			$tmp2 = "";
			$xml_data = qq[
			<transaction>
				<profileTransAuthCapture>
					<amount>$tmp1</amount>
					<customerProfileId>$order{customerProfileId}</customerProfileId>
					<customerPaymentProfileId>$order{customerPaymentProfileId}</customerPaymentProfileId>
					<order>
						<description>Manual recharge</description>
					</order>
					<recurringBilling>false</recurringBilling>
				</profileTransAuthCapture>
			</transaction>
			];
			$MyData = &authorize_cim_transaction("createCustomerProfileTransactionRequest",$xml_data);
			$order{debug} .= "authcapture over CIM profile. status=$MyData->{STATUS_OK} - $MyData->{STATUS_MESSAGE} ! ";
			if ($MyData->{STATUS_OK} eq 0) {
				#
				# we count cc-errors for this service. 
				$order{debug} .= "no way to authcapture over CIM! ";
				$order{message}="Error in AuthCapture over payment profile";
				$tmp = &data_get("service_data",$order{service_id},"CIM_ERRORS");
				$tmp = ($tmp eq "") ? 0 : $tmp;
				$tmp++;
				&data_set("service_data",$order{service_id},"CIM_ERRORS",$tmp);
				if ($tmp>=2) {
					$order{debug} .= "too many errors ($tmp) for this CC_profile. Flag as error! ";
					&multilevel_securedata_cc_error_set($order{cim_profile_cc_id});
					# &multilevel_securedata_cc_error_set($order{service_id}); # now we use cc_profile_id instead service_id in this api
				} else {
					$order{debug} .= "$tmp errors for this CC_profile! ";
				}
			} else {
				#
				# if capture is ok let logic flow
				$order{debug} .= "authcapture over CIM was ok! ";
			}
		} else {
			#
			# bad CIM profile. 
			# TODO: do better debug to track errors
			$order{debug} .= "AUTHORIZE_ACIM/PCIM/CIM payment profile with error. $order{cim_profile_status_message}! ";
			$order{message}="Error in AUTHORIZE_ACIM/PCIM/CIM payment profile";
		}
	}
	#
	#--------------------------------------
	# COMMISSION_CRED step 1
	# Create new invoice with status=0 and get id of this invoice and add commissions on ths invoice
	#--------------------------------------
	if ( ($order{message} eq "") &&  ("\U$order{type}" eq "COMMISSION_CRED")  ){
		$order{debug} .= "COMMISSION INVOICE we have to create invoice for this commissions! ";
		#
		# create new invoice with status=0 and get id 
		$sql = "
			insert into service_commission_invoice
			(  creation_date,  status,  value,                  service_id            ) values
			(  now(),          '0',     '$order{value_credit}', '$order{service_id}'  )
		";
		database_do($sql);
		%hash = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
		$order{commission_invoice_id} = $hash{1};
		$order{debug} .= "COMMISSION INVOICE invoice_id = $order{commission_invoice_id} ! ";
		#
		# add comissoes on this invoice
		if ($order{commission_invoice_id} ne "") {
			$order{debug} .= "COMMISSION INVOICE add commissions to invoice ! ";
			$sql = "
				UPDATE service_commission
				SET invoice_id='$order{commission_invoice_id}'
				WHERE service_id='$order{service_id}' and invoice_id is null and id in ($order{commissions_ids})
				";
				database_do($sql);
		} else {
			$order{debug} .= "COMMISSION INVOICE error creating invoice ! ";
			$order{message}="Error in commissions invoice id";
		}
	}
	#
	#--------------------------------------
	# authorize step 1
	# send request to authorize to debit cc
	# (Old authorize proccess. we need delete later)
	#--------------------------------------
#	if ( ($order{message} eq "") &&  ("\U$order{type}" eq "AUTHORIZE_CC")  ){
#		#
#		# gerar dados de agora
#		$order{card_fingerprint} = key_md5("CC|$order{card_number}|$order{card_date}");
#		$order{debug}  .= "start authorize ! ";
#		#
#		# criar detail na database
#		$sql = "
#			insert into credit_detail_authorize
#			(  date,  status, value,                  service_id,           card_fingerprint            ) values
#			(  now(), '0',    '$order{value_money}', '$order{service_id}', '$order{card_fingerprint}'   )
#		";
#		database_do($sql);
#		%hash = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
#		$order{credit_authorize_detail_id} = $hash{1};
#		$order{debug}  .= "authorize detail ok ! ";
#		#
#		# criar objeto pra enviar por https
#		$tmp = ($app{authorize_api_is_test} eq 1) ? "TRUE" : "FALSE";
#		if ($order{card_address} ne "") {
#			$object = {
#			x_test_request	=> $tmp,
#			x_login			=> $app{authorize_api_login_id},
#			x_tran_key		=> $app{authorize_api_tran_key},
#			x_version		=> "3.1",
#			x_delim_char	=> "|",
#			x_delim_data	=> "TRUE",
#			x_adc_url		=> "FALSE",
#			x_method		=> "CC",
#			x_type			=> "AUTH_CAPTURE",
#			x_first_name	=> $order{card_first_name},
#			x_last_name		=> $order{card_last_name},
#			x_address		=> $order{card_address},
#			x_city			=> $order{card_city},
#			x_state			=> $order{card_state},
#			x_zip			=> $order{card_zip},
#			x_card_code		=> $order{card_code},
#			x_cust_id		=> $order{service_id},
#			x_invoice_num	=> $order{credit_authorize_detail_id},
#			x_card_num		=> $order{card_number},
#			x_exp_date		=> $order{card_date},
#			x_description	=> $order{text},
#			x_amount		=> $order{value_money},
#			};
#		} else {
#			$object = {
#			x_test_request	=> $tmp,
#			x_login			=> $app{authorize_api_login_id},
#			x_tran_key		=> $app{authorize_api_tran_key},
#			x_version		=> "3.1",
#			x_delim_char	=> "|",
#			x_delim_data	=> "TRUE",
#			x_adc_url		=> "FALSE",
#			x_method		=> "CC",
#			x_type			=> "AUTH_CAPTURE",
#			x_first_name	=> $order{card_first_name},
#			x_last_name		=> $order{card_last_name},
#			x_card_code		=> $order{card_code},
#			x_cust_id		=> $order{service_id},
#			x_invoice_num	=> $order{credit_authorize_detail_id},
#			x_card_num		=> $order{card_number},
#			x_exp_date		=> $order{card_date},
#			x_description	=> $order{text},
#			x_amount		=> $order{value_money},
#			};
#		}
#		#
#		# tentar collect o dinheiro
#		$order{debug}  .= "useragent.";
#		$useragent	= LWP::UserAgent->new( protocols_allowed => ["https"] );
#		$order{debug}  .= "ok ! ";
#		$order{debug}  .= "request($app{authorize_api_is_test}).";
#		$tmp = ($app{authorize_api_is_test} eq 1) ? "https://test.authorize.net/gateway/transact.dll" : "https://secure.authorize.net/gateway/transact.dll";
#		$request	= POST($tmp, $object );
#		$order{debug}  .= "ok ! ";
#		$order{debug}  .= "response.";
#		$response	= $useragent->request( $request );
#		unless( $response->is_success ){
#			$order{debug} .= "error status=".$response->status_line." content=".$response->content." ! ";
#			$order{message} = "No connection with payment gateway.";
#		} else {
#			$order{debug} .= "ok ! ";
#		}
#	}
#	#
	#--------------------------------------
	# authorize step 2
	# get authorize response and check
	# (Old authorize proccess. we need delete later)
	#--------------------------------------
#	if ( ($order{message} eq "") &&  ("\U$order{type}" eq "AUTHORIZE_CC")  ){
#		#
#		# separa os dados da resposta
#		@names = ("ResponseCode", "ResponseSubCode", "ResponseReasonCode", "ResponseReasonText", "ApprovalCode", "AVSResultCode", "TransactionID", "InvoiceNumber", "Description", "Amount", "Method", "TransactionType", "CustomerID", "CardholderFirstName", "CardholderLastName", "Company", "BillingAddress", "City", "State", "ZIP/PostalCode", "Country", "Phone", "Fax", "EMailAddress", "ShiptoFirstName", "ShiptoLastName", "ShiptoCompany", "ShiptoAddress", "ShiptoCity", "ShiptoState", "ShiptoZIP/PostalCode", "ShiptoCountry", "TaxAmount", "DutyAmount", "FreightAmount", "TaxExemptFlag", "PONumber", "MD5Hash", "CardCodeVerificationResult", "Reservedforfutureuse_40", "Reservedforfutureuse_41", "Reservedforfutureuse_42", "Reservedforfutureuse_43", "Reservedforfutureuse_44", "Reservedforfutureuse_45", "Reservedforfutureuse_46", "Reservedforfutureuse_47", "Reservedforfutureuse_48", "Reservedforfutureuse_49", "Reservedforfutureuse_50", "Reservedforfutureuse_51", "Reservedforfutureuse_52", "Reservedforfutureuse_53", "Reservedforfutureuse_54", "Reservedforfutureuse_55", "Reservedforfutureuse_56", "Reservedforfutureuse_57", "Reservedforfutureuse_58", "Reservedforfutureuse_59", "Reservedforfutureuse_60", "Reservedforfutureuse_61", "Reservedforfutureuse_62", "Reservedforfutureuse_63", "Reservedforfutureuse_64", "Reservedforfutureuse_65", "Reservedforfutureuse_66", "Reservedforfutureuse_67", "Reservedforfutureuse_68", "Merchantdefined");
#		@values = split /\Q|/, $response->content;
#		$count = $#values;
#		for ($i=0; $i <=$count; $i++) { $authorize_answer{$names[$i]} = $values[$i]; }
#		$order{debug} .= "split $count data in authorize answer ! ";
#		$sql = "
#			update credit_detail_authorize set
#			status='$authorize_answer{ResponseCode}',
#			authorize_response_subcode='$authorize_answer{ResponseSubCode}',
#			authorize_response_reason_code='$authorize_answer{ResponseReasonCode}',
#			authorize_approval_code='$authorize_answer{ApprovalCode}',
#			authorize_avs_result_code='$authorize_answer{AVSResultCode}',
#			authorize_transaction_id='$authorize_answer{TransactionID}',
#			authorize_method='$authorize_answer{Method}',
#			authorize_transaction_type='$authorize_answer{TransactionType}',
#			authorize_card_code_result='$authorize_answer{CardCodeVerificationResult}'
#			where id='$order{credit_authorize_detail_id}'
#		";
#		$order{debug} .= "update authorize detail ! ";
#		database_do($sql);
#		#
#		# verifica md5
#		#
#		# verifica acc, invoice e valor
#		#	x_cust_id			=> $order{account_id},
#		#	x_invoice_num		=> $order{credit_authorize_detail_id},
#		#	x_card_num			=> $order{card_number},
#		#	x_exp_date			=> $order{card_date},
#		#	x_description		=> $order{text},
#		#	x_amount			=> $order{value_money},
#		if ($authorize_answer{ResponseCode} ne 1) {
#			$order{debug} .= "bad answer from authorize ! ";
#			$order{message} = "Error with payment gateway. $authorize_answer{ResponseReasonText}";
#		}
#	}
#	#
	#--------------------------------------
	# Now we have all ok (and money collected)
	# time to give love for our customer
	#--------------------------------------
	if ($order{message} eq "") {
		#
		#--------------------------------------
		# Create credit at table
		#--------------------------------------
		$sql = "
			insert into credit
			(  date,  status,  credit_type,    source_type,           source_info,           value,                 credit,                 text,           service_id           ) values
			(  now(), '1',    '$order{type}', '$order{source_type}', '$order{source_info}', '$order{value_money}', '$order{value_credit}', '$order{text}', '$order{service_id}'  )
		";
		database_do($sql);
		%hash = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
		$order{new_credit_id} = $hash{1};
		$order{debug} .= "credit $order{new_credit_id} created ! ";
		#
		#--------------------------------------
		# Add credit to service
		#--------------------------------------
		&database_do("update service set balance = balance + $order{value_credit} where id = '$order{service_id}' ");
		%tmp = database_select_as_hash("select 1,1,balance from service where id='$order{service_id}'","flag,value");
		$order{debug} .= "add credit=$order{value_credit} on balance LBAC=$tmp{1}{value} ! ";
		&data_set("service_data",$order{service_id},"LBAC",$tmp{1}{value});
		#
		#--------------------------------------
		# update authorize na tabela
		#--------------------------------------
#		if ( ("\U$order{type}" eq "AUTHORIZE_CC")  ){
#			$sql = "
#				update credit_detail_authorize set
#				credit_id='$order{new_credit_id}'
#				where id='$order{credit_authorize_detail_id}'
#			";
#			database_do($sql);
#			$order{debug} .= "update authorize detail with credit_id ! ";
#		}
		#
		#--------------------------------------
		# update CIM profile data
		#--------------------------------------
		if ( ($order{type} eq "AUTHORIZE_CIM") || ($order{type} eq "AUTHORIZE_ACIM")  || ($order{type} eq "AUTHORIZE_PCIM") ) {
			$sql = "
				update credit
				set service_profile_cc_id='$order{cim_profile_cc_id}'
				where id='$order{new_credit_id}'
			";
			database_do($sql);
			$order{debug} .= "update call data with profile CC id ! ";
		}
		#
		#--------------------------------------
		# update coupon data (if exists)
		#--------------------------------------
		if ( ($order{coupon_stock_id} ne "") || ($order{coupon_slice_index}	ne "") ) {
			$sql = "
				update credit
				set
				coupon_slice_index='$order{coupon_slice_index}',
				coupon_stock_id='$order{coupon_stock_id}'
				where id='$order{new_credit_id}'
			";
			database_do($sql);
			$order{debug} .= "update coupon_stock_id=$order{coupon_stock_id} coupon_slice_index=$order{coupon_slice_index} ! ";
		}
		#
		#--------------------------------------
		# update invoice
		#--------------------------------------
		if ( ("\U$order{type}" eq "COMMISSION_CRED")  ){
			#
			# marca invoice foi paga
			$sql = "
				update service_commission_invoice  set status=1, credit_id='$order{new_credit_id}'
				where id = '$order{commission_invoice_id}'
			";
			database_do($sql);
			$order{debug} .= "update invoice status ! ";
		}
		#
		#--------------------------------------
		# Money IN, lets give zeno-type commission to this service parents
		# red-alert commission over COMMISSION_CRED .. :(
		# i dont like it. i know is the same as request check
		# and re-add as money, soo, in fact is money-in...
		# but i still have to think in zenofon commission over
		# zenofon commission.... how much we are commission!
		#--------------------------------------
		$order{value_to_use_as_commission_base} = 0;
		$order{value_to_use_as_commission_base} = ($order{type} eq "CASH"			) ? $order{value_money} : $order{value_to_use_as_commission_base};
		$order{value_to_use_as_commission_base} = ($order{type} eq "AUTHORIZE_CC"	) ? $order{value_money} : $order{value_to_use_as_commission_base};
		$order{value_to_use_as_commission_base} = ($order{type} eq "AUTHORIZE_CIM"	) ? $order{value_money} : $order{value_to_use_as_commission_base};
		$order{value_to_use_as_commission_base} = ($order{type} eq "AUTHORIZE_ACIM"	) ? $order{value_money} : $order{value_to_use_as_commission_base};
		$order{value_to_use_as_commission_base} = ($order{type} eq "AUTHORIZE_PCIM"	) ? $order{value_money} : $order{value_to_use_as_commission_base};
		$order{value_to_use_as_commission_base} = ($order{type} eq "COMMISSION_CRED") ? $order{value_credit}: $order{value_to_use_as_commission_base};
		if ( $order{value_to_use_as_commission_base} > 0 ) {
			# 
			# old way
			#if ($app{default_commission_base} > 0) {
			#	%tmp_hash = database_select_as_hash("select 1,1,parent_service_id from service_tree where service_id='$order{service_id}'","flag,id");
			#	if ( ($tmp_hash{1}{flag} eq 1) && ($tmp_hash{1}{id} ne "") ) {
			#		$order{commission_value} = ( $order{value_to_use_as_commission_base} * ($app{default_commission_base}/100) );
			#		%commission_data = ();
			#		$commission_data{activation_date_1} = &data_get("system_config","commission","credit_activation_date_1");
			#		$commission_data{activation_date_2} = &data_get("system_config","commission","credit_activation_date_2");
			#		$commission_data{service_id}		= $tmp_hash{1}{id};
			#		$commission_data{from_service_id}	= $order{service_id};
			#		$commission_data{credit_id}			= $order{new_credit_id};
			#		$commission_data{value} 			= $order{commission_value};
			#		$commission_data{type} 				= "CREDIT";
			#		$commission_data{email_template} 	= "alert.credit.commission";
			#		$commission_data{mode} 				= ($app{default_commission_mode} eq "ZENO") ? "ZENO" : "SINGLE";
			#		%commission_data = &multilevel_commission_aXdXd(%commission_data);
			#	}
			#}
			# 
			# new way
			%commission_data = ();
			$commission_data{service_id}					= &multilevel_service_get_parent($order{service_id});
			$commission_data{from_service_id}				= $order{service_id};
			$commission_data{commission_type_engine} 		= "REFERRAL_RECHARGE";
			$commission_data{value_percentage_base}			= $order{value_to_use_as_commission_base};
			$commission_data{credit_id}						= $order{new_credit_id};
			%commission_data = &multilevel_commission_new(%commission_data);
		}
		#
		#--------------------------------------
		# all done :) lets flag ok 
		#--------------------------------------
		$order{message}	= "Aproved";
		$order{ok}	= 1;
		$order{debug}  .= "finish ok ! ";
	}
	#
	#--------------------------------------
	# log in txt 
	#--------------------------------------
	if ($order{ok} eq 1) {
		open (OUTE,">>$app_root/website/log/credit.log");
	} else {
		open (OUTE,">>$app_root/website/log/credit.error.log");
	}
	print OUTE "\n----------------------------------------\n";
	print OUTE `date`;
	foreach (sort keys %order) {
		if ($_ eq "card_number") 	{print OUTE "ORDER_DATA ---> $_=XXXXXXXXXXXX".substr($order{card_number},-4,4)."\n";next}
		if ($_ eq "debug") 			{next;}
		print OUTE "ORDER_DATA ---> $_=$order{$_}\n";
	}
	foreach (split(/\!/,$order{debug})) {
		if (index($_,"AUTHORIZE ids") ne -1) 			{next;}
		print OUTE "DEBUG ---> $_\n";
	}
	foreach (sort keys %authorize_answer) {	print OUTE "AUTHORIZE_ANSWER ---> $_=$authorize_answer{$_}\n";}
	print OUTE "\n";
	close(OUTE);
	#
	#--------------------------------------
	# return
	#--------------------------------------
	return %order;
}
#------------------------
#
#------------------------
# old commission
#------------------------
sub multilevel_commission_add(){
	local(%commission) = @_;
	local(%hash, %tmp_hash,$sql,$sql_credit_id,$sql_from_service_id,$loop_service_id,$loop_value,$loop_deep );
	$commission{status_message} = "";
	$commission{status_ok} = 0;
	$commission{debug} = "";
	#
	#--------------------------------------
	# verifica se tem o basico pra seguir
	#--------------------------------------
	if ($commission{status_message} eq "") {
		$commission{activation_date_1} = ($commission{activation_date_1} eq "") ? 45 : $commission{activation_date_1};
		$commission{activation_date_2} = ($commission{activation_date_2} eq "") ? 90 : $commission{activation_date_2};
		if (&form_check_integer	($commission{activation_date_1})	ne 1)	{$commission{status_message}="Wrong activation date 1";	}
		if (&form_check_integer	($commission{activation_date_2})	ne 1)	{$commission{status_message}="Wrong activation date 2";	}
		if (&form_check_integer	($commission{service_id})			ne 1)	{$commission{status_message}="Wrong service";	}
		if (&form_check_float	($commission{value})				ne 1)	{$commission{status_message}="Wrong value";		}
		if (&form_check_string	($commission{title},"allow_blank")	ne 1)	{$commission{status_message}="Wrong title";		}
		if (index("|SINGLE|ZENO|","|$commission{mode}|") eq -1)	{$commission{status_message}="Unknown mode"; 	}
		if (index("|CREDIT|MANUAL|NEWF|NEWFCALL|","|$commission{type}|") eq -1)	{$commission{status_message}="Unknown type"; 	}
	}
	$commission{debug} .= "first check ok\n";
	#
	#--------------------------------------
	# verifica segunda parte
	#--------------------------------------
	if ($commission{status_message} eq "") {
		%hash = database_select_as_hash("select 1,1 from service where service.id='$commission{service_id}'  ","flag");
		unless ($hash{1}{flag} eq 1) {$commission{status_message}="Unknown service";	}
		if ( ($commission{value}>100) || ($commission{value}<=0) )	{$commission{status_message}="Out of range value";		}
		if ( ($commission{activation_date_1}>3650) || ($commission{activation_date_1}<0) )	{$commission{status_message}="Out of range activation date 1";		}
		if ( ($commission{activation_date_2}>3650) || ($commission{activation_date_2}<0) )	{$commission{status_message}="Out of range activation date 1";		}
	}
	if ($commission{status_message} eq "") {
		if (index("|CREDIT|NEWF|NEWFCALL|","|$commission{type}|") ne -1) {
			if (&form_check_integer	($commission{from_service_id})	ne 1)	{$commission{status_message}="Wrong from service";	}
			%hash = database_select_as_hash("select 1,1 from service where service.id='$commission{service_id}' ","flag");
			unless ($hash{1}{flag} eq 1) {$commission{status_message}="Unknown service";	}
		}
		if (index("|CREDIT|","|$commission{type}|") ne -1) {
			if (&form_check_integer	($commission{credit_id})	ne 1)	{$commission{status_message}="Wrong credit id";	}
		}
	}
	$commission{debug} .= "second check ok\n";
	#
	#--------------------------------------
	# aplica comissao SINGLE
	#--------------------------------------
	if ($commission{status_message} eq "") {
		if ($commission{mode} eq "SINGLE") {
			$commission{debug} .= "enter single commission\n";
			$sql_from_service_id 	= ($commission{from_service_id} eq "") ? "NULL" : "'$commission{from_service_id}'";
			$sql_credit_id 			= ($commission{credit_id} 		eq "") ? "NULL" : "'$commission{credit_id}'";
			$sql = "
			insert into service_commission
			(creation_date, activation_date_1,                                             activation_date_2,                                             service_id,                 from_service_id,       credit_id,       type,                  title,                 deep,  value                 ) values
			(now(),         date_add(now(),interval $commission{activation_date_1} day),   date_add(now(),interval $commission{activation_date_2} day),   '$commission{service_id}',  $sql_from_service_id,  $sql_credit_id,  '$commission{type}',   '$commission{title}',  '1',   '$commission{value}'  )
			";
			$commission{debug} .= "SQL=$sql\n";
			&database_do($sql);
			%hash = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
			$commission{commission_id} = $hash{1};
			$commission{debug} .= "id=$commission{commission_id}\n";
			if ($commission{email_template} ne "") {
				$tmp =&multilevel_commission_notify_by_email($commission{commission_id},$commission{email_template});
				$commission{debug} .= "Send email ($commission{email_template}) ($tmp)\n";
			}
			$commission{status_ok} = 1;
		}
	}
	#
	#--------------------------------------
	# aplica comissao ZENO
	#--------------------------------------
	if ($commission{status_message} eq "") {
		if ($commission{mode} eq "ZENO") {
			my $loop_value 			= $commission{value};
			my $loop_service_id 	= $commission{service_id};
			#
			# roda no loop em varios niveis (mas nao infinito)
			$commission{debug} .= "enter zeno\n";
			foreach $loop_deep (1..50){
				#
				# anda no loop, (calula valor e porcentagem)
				$loop_value 		= ($loop_value/2);
				#
				# se tem refer, pega dados dele
				$sql = "
				select 1,1,can_collect_commission,deleted
				from service, service_status
				where service.id = '$loop_service_id' and service.status = service_status.id
				";
				%tmp_hash = database_select_as_hash($sql,"flag,can_collect_commissions,deleted");
				$commission{debug} .= "CHECK\nid=$loop_service_id\nvalue=$loop_value\n$sql\nflag=$tmp_hash{1}{flag}\ncan=$tmp_hash{1}{can_collect_commission}\ndel=$tmp_hash{1}{deleted}\n\n";
				#
				# add comission se habilitado
				if ( ($tmp_hash{1}{flag} eq 1) && ($tmp_hash{1}{can_collect_commissions} eq 1) && ($tmp_hash{1}{deleted} eq 0)  ) {
					$tmp = $commission{service_id};
					$tmp = ($tmp eq $loop_service_id) ? "" : $tmp;
					$tmp = ($commission{from_service_id} ne "") ? $commission{from_service_id} : $tmp;
					$sql_from_service_id 	= ($tmp eq "") ? "NULL" : "'$tmp'";
					$sql_credit_id 			= ($commission{credit_id} 		eq "") ? "NULL" : "'$commission{credit_id}'";
					$sql = "
					insert into service_commission
					(creation_date, activation_date_1,                                             activation_date_2,                                             service_id,          from_service_id,       credit_id,       type,                  title,                 deep,           value          ) values
					(now(),         date_add(now(),interval $commission{activation_date_1} day),   date_add(now(),interval $commission{activation_date_2} day),   '$loop_service_id',  $sql_from_service_id,  $sql_credit_id,  '$commission{type}',   '$commission{title}',  '$loop_deep',   '$loop_value'  )
					";
					&database_do($sql);
					%hash = database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
					$commission_id = $hash{1};
					$commission{commission_id} = ($commission{commission_id} eq "") ?  $hash{1} : $commission{commission_id};
					$commission{debug} .= "ADD\nid=$commission_id\n$sql\n\n";
					if ($commission{email_template} ne "") {
						$tmp = &multilevel_commission_notify_by_email($commission_id,$commission{email_template});
						$commission{debug} .= "Send email ($commission{email_template}) ($tmp)\n";
					}
					$commission{status_ok} = 1;
				}
				#
				# pega refer desse servico
				%hash = database_select_as_hash("select 1,1,parent_service_id from service_tree where service_id='$loop_service_id'","flag,id");
				$commission{debug} .= "GET REFER\nselect 1,1,parent_service_id from service_tree where service_id='$loop_service_id'\nflag=$hash{1}{flag} id=$hash{1}{flag}\n\n";
				# se nao tem refer, morre o loop todo
				if ($hash{1}{flag} ne 1)	{last}
				if ($hash{1}{id} eq "")		{last}
				$loop_service_id = $hash{1}{id};
			}
		}
	}
	$commission{status_message} = ( ($commission{status_ok} eq 1) && ($commission{status_message} eq "") ) ? "Aproved" : $commission{status_message};
	return %commission;
}
sub multilevel_commission_notify_by_email(){
	local($commission_id,$email_template) = @_;
	local(%data, %hash,$sql,%email);
	%email = ();
	if ($email_template eq "") {return -1}
	$sql = "
	SELECT
		1,
		1,
		service_commission.title,
		service_commission.type,
		service_commission.service_id,
		service_commission.from_service_id,
		service_commission.credit_id,
		service_commission.deep,
		service_commission.value,
		service.name,
		service.email
	FROM
		service_commission, service
	where
		service_commission.id=$commission_id and
		service_commission.service_id=service.id
	";
	%hash = database_select_as_hash($sql,"flag,commission_title,commission_type,service_id,from_service_id,credit_id,commission_deep,commission_value,service_name,service_email");
	if ($hash{1}{flag} ne 1) {return -2}
	if ($hash{1}{service_email} eq "") {return -3}
	if (&data_get("service_data",$hash{1}{service_id},"trigger_nc") ne 1) {return -4}
	%data = %{$hash{1}};
	%email = ();
	$email{template}				= $email_template;
	$email{to}						= $data{service_email};
	$email{dic}{service_name}		= $data{service_name};
	$email{dic}{service_email}		= $data{service_name};
	$email{dic}{commission_title}	= "Commission";
	$email{dic}{commission_title}	= ($data{commission_type} eq "CREDIT") 	? "Friend Credit Commission" 		: $email{dic}{commission_title} ;
	$email{dic}{commission_title}	= ($data{commission_type} eq "NEWF") 	? "New Friend Commission" 			: $email{dic}{commission_title} ;
	$email{dic}{commission_title}	= ($data{commission_type} eq "NEWFCALL")? "Friend First Call Commission"	: $email{dic}{commission_title} ;
	$email{dic}{commission_title}	= ($data{commission_type} eq "MANUAL") 	? "Manual Commission" 				: $email{dic}{commission_title} ;
	$email{dic}{commission_title}	= ($data{commission_title} ne "") 		? "Commission: $data{commission_title}" 		: $email{dic}{commission_title} ;
	$v = $data{commission_value};
	$s = 2;
	$s = ( $v < 0.20) ? 3 : $s;
	$s = ( $v < 0.02) ? 4 : $s;
	$email{dic}{commission_value}	= &format_number($v,$s);
	$email{dic}{branch_distance}	= "your friend";
	$email{dic}{branch_distance}	= ($data{commission_deep} eq 2) ? "one person away" : $email{dic}{branch_distance};
	$email{dic}{branch_distance}	= ($data{commission_deep} > 2) ? ($data{commission_deep}-1)." people away" : $email{dic}{branch_distance};
	$email{dic}{from}				= "";
	$email{dic}{from_service_name}	= "";
	if ($data{from_service_id} ne "") {
		%hash = database_select_as_hash("select 1,1,name from service where id=$data{from_service_id}","flag,name");
		if ($hash{1}{flag} eq 1) {
			$email{dic}{from_service_name} = &format_trim_name($hash{1}{name}, ($data{commission_deep}>2)?1:0);
			$email{dic}{from} = "from \"$email{dic}{from_service_name}\" ($email{dic}{branch_distance})";
		}
	}
	return &multilevel_send_email(%email);
}
#------------------------


#
#------------------------
# clickchain (protect from url forge)
#------------------------
sub multilevel_clickchain_set(){
	local ($prefix) = @_;
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash);
	$out = substr($prefix,0,2).time;
	$tmp = &active_session_get("clickchain");
	&active_session_set("clickchain",substr("$out,$tmp",0,200));
	return $out;
}
sub multilevel_clickchain_check(){
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
# ip flood functions
#------------------------
sub multilevel_check_ip_flood(){
	if ($ENV{REMOTE_ADDR} eq "127.0.0.1") {return}
	local ($section) = @_;
	local ($ip) = $ENV{REMOTE_ADDR};
	local ($buf,$out,$tmp,$tmp1,$tmp2,%hash,$counter_1,$counter_2,$timestamp);
	$counter_1	= 0;
	$counter_2	= 0;
    %hash = database_select_as_hash("SELECT 1,1,counter_1,counter_2,unix_timestamp(timestamp) FROM security_ip_flood where ip='$ip'","flag,counter_1,counter_2,timestamp");
	if ($hash{1}{flag} eq 1) {
		$counter_1	= ($hash{1}{counter_1}	ne "") ? $hash{1}{counter_1}: 0;
		$counter_2	= ($hash{1}{counter_2}	ne "") ? $hash{1}{counter_2}: 0;
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
	if ( ($counter_1 > 10) || ($counter_2 > 60) ) {
		&action_history("ipflood:myaccount",('value_new'=>$ENV{REMOTE_ADDR}, 'value_old'=>"$section"  ));
		$buf = "";
		$buf .= "DATE $today{DATE_TO_PRINT} $today{TIME_TO_PRINT} \n";
		$buf .= "DATE_ID = $today{DATE_ID}$today{TIME_ID} \n";
		$buf .= "SECTION = $section \n";
		$buf .= "COUNTERS = $ip - ".(time-$timestamp)." - $counter_1 - $counter_2\n";
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
sub DELETE_multilevel_ip_flood(){
	local ($ip) = @_;
	local($out,$tmp,$tmp1,$tmp2,%hash,$counter_1,$counter_2,$timestamp);
	$counter_1	= 0;
	$counter_2	= 0;
    %hash = database_select_as_hash("SELECT 1,1,counter_1,counter_2,unix_timestamp(timestamp) FROM security_ip_flood where ip='$ip'","flag,counter_1,counter_2,timestamp");
	if ($hash{1}{flag} eq 1) {
		$counter_1	= ($hash{1}{counter_1}	ne "") ? $hash{1}{counter_1}: 0;
		$counter_2	= ($hash{1}{counter_2}	ne "") ? $hash{1}{counter_2}: 0;
		$timestamp	= ($hash{1}{timestamp}	ne "") ? $hash{1}{timestamp}: time;
		if ( (time-$timestamp)<(60) 		) {$counter_1++;} else {$counter_1 = 0;}
		if ( (time-$timestamp)<(60*60*10) 	) {$counter_2++;} else {$counter_2 = 0;}
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
			(ip,     timestamp,  counter_1,     counter_2     ) values
			('$ip',  now(),      '$counter_1',  '$counter_2'  )
		");
		$counter_1	= 1;
		$counter_2	= 1;
	}
	return ($counter_1,$counter_2,$timestamp);
}
#
#------------------------
# email
#------------------------
# create queue at database and service to consume this queue
sub multilevel_send_email(){
	local (%info) = @_;
	$info{from} = "system\@zenofon.com";
	$info{subject} = "ZenoFon message";
	$file = "$email_template_folder/email.$info{template}.txt";
	$buf = "";
	if (-e $file){
		open(EMAILTEMPLATE,$file);
		while(<EMAILTEMPLATE>) {$buf .= $_};
		close(EMAILTEMPLATE);
		foreach $n (keys %{$info{dic}}) {
			$v = $info{dic}{$n};
			$r = "\U#$n#";
			$buf =~ s/$r/$v/eg;
		}
		send_email($info{from},$info{to},$info{subject},$buf,1);
		return 1;
	} else {
		return 0;
	}
}

