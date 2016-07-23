use A2B;
use YAML;
my $a2b = A2B->new;
my $res = $a2b->sendcommand('action' => 'command', 'command' => 'core show channels concise', 2);
print $res->{body};