#!/usr/bin/perl

%spool = ();
while (1) {
    while (</tmp/*.konf>) {
        ($conference, $minutes) = $_ =~ m{/tmp/(\d+)\-(\d+)\.konf};
        
        warn "keep $conference in $minutes minutes";
        
        unlink $_;    
        
        next unless $conference;
        $spool{$conference}{seconds} = $minutes * 60;
        $spool{$conference}{start} = time;
        
    }
    
    for (keys %spool) {
        if (time - $spool{$_}{start} > $spool{$_}{seconds}) {
            warn "kill conference=$_\n";
            
            system("setsid asterisk -rx \"konference end $_\"");
            delete $spool{$_};
        }
    }
    sleep 1;
}
