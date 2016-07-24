use Net::AMQP::RabbitMQ;
my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "queuename");
$mq->publish(1, "queuename", "Hi there!");
my $gotten = $mq->get(1, "queuename");
print $gotten->{body} . "\n";
$mq->disconnect();