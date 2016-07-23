use Net::WebSocket::Server;
use Net::AMQP::RabbitMQ;
require "/salzh/salzh/outbound/lib/include.pl";


my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");

Net::WebSocket::Server->new(
    listen => 8080,
    on_connect => sub {
        my ($serv, $conn) = @_;
        $conn->on(
            utf8 => sub {
                my ($conn, $msg) = @_;
                warn "Get MSG: $msg";
                $conn->send_utf8($msg);
            },
        );
    },
    tick_period => 1,
    on_tick => \&check_incoming_event,
)->start;

sub check_incoming_event () {
	($serv) = @_;
	$msg = $mq->get(1, "incoming");
  	print $msg->{body} . "\n";
  	$event_str = $msg->{body};
	return if !$event_str;
	$_->send_utf8($event_str) for $serv->connections;
    
}
