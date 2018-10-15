use strict;
use warnings;
use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';
use JSON;
use Getopt::Long;
use DBI;


my $ep_pull;
my $ep_sub;

my $dsn = 'DBI:mysql:database=tokenapi;host=localhost';
my $db_user = 'tokenapi';
my $db_password = 'ce1Shish';
my $commit_every = 10;


my $ok = GetOptions
    ('pull=s'    => \$ep_pull,
     'sub=s'     => \$ep_sub,
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or
    (not $ep_pull and not $ep_sub) or
    ($ep_pull and $ep_sub) )
{
    print STDERR "Usage: $0 [options...]\n",
    "The utility connects to EOS ZMQ PUB or PUSH socket and \n",
    "updates token balances in the database\n",
    "Options:\n",
    "  --pull=ENDPOINT  connect to a PUSH socket\n",
    "  --sub=ENDPOINT   connect to a PUB socket\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

        

my $dbh = DBI->connect($dsn, $db_user, $db_password,
                       {'RaiseError' => 1, AutoCommit => 0,
                        mysql_server_prepare => 1});
die($DBI::errstr) unless $dbh;

my $sth_checkresblock = $dbh->prepare
    ('SELECT block_num FROM TOKENAPI_LATEST_RESOURCE ' .
     'WHERE account_name=?');

my $sth_inslastres = $dbh->prepare
    ('INSERT INTO TOKENAPI_LATEST_RESOURCE ' . 
     '(account_name, block_num, block_time, trx_id, ' .
     'cpu_weight, net_weight, ram_quota, ram_usage) ' .
     'VALUES(?,?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, ' .
     'cpu_weight=?, net_weight=?, ram_quota=?, ram_usage=?');


my $sth_checkcurrblock = $dbh->prepare
    ('SELECT block_num FROM TOKENAPI_LATEST_CURRENCY ' .
     'WHERE account_name=? AND contract=? AND currency=?');


my $sth_inslastcurr = $dbh->prepare
    ('INSERT INTO TOKENAPI_LATEST_CURRENCY ' . 
     '(account_name, block_num, block_time, trx_id, contract, currency, amount) ' .
     'VALUES(?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, amount=?');

my $sth_checkcontract = $dbh->prepare
    ('SELECT block_num FROM TOKENAPI_CONTRACTS ' .
     'WHERE account_name=? AND action_name=?');

my $sth_inscontract = $dbh->prepare
    ('INSERT INTO TOKENAPI_CONTRACTS ' . 
     '(account_name, action_name, block_num, block_time, trx_id) ' .
     'VALUES(?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?');



my $ctxt = zmq_init;
my $socket;

if( defined($ep_pull) )
{
    $socket = zmq_socket($ctxt, ZMQ_PULL);
    my $rv = zmq_connect( $socket, $ep_pull );
    die($!) if $rv;
}
else
{
    $socket = zmq_socket($ctxt, ZMQ_SUB);
    my $rv = zmq_connect( $socket, $ep_sub );
    die($!) if $rv;
    $rv = zmq_setsockopt( $socket, ZMQ_SUBSCRIBE, pack('VV', 0, 0) );
    die($!) if $rv;
}



my $json = JSON->new->pretty->canonical;
my $uncommitted = 0;

my $msg = zmq_msg_init();
while( zmq_msg_recv($msg, $socket) != -1 )
{
    my $data = zmq_msg_data($msg);
    my ($msgtype, $opts, $js) = unpack('VVa*', $data);
    if( $msgtype == 0 )  # action and balances
    {
        my $action = $json->decode($js);
        
        my $tx = $action->{'action_trace'}{'trx_id'};
        my $block_time =  $action->{'block_time'};
        $block_time =~ s/T/ /;

        my $block_num = $action->{'block_num'};
                
        foreach my $bal (@{$action->{'resource_balances'}})
        {
            my $account = $bal->{'account_name'};
            
            $sth_checkresblock->execute($account);
            my $r = $sth_checkresblock->fetchall_arrayref();
            if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num )
            {
                next;
            }
            
            my $cpuw = $bal->{'cpu_weight'}/10000.0;            
            my $netw = $bal->{'net_weight'}/10000.0;
            my $quota = $bal->{'ram_quota'};
            my $usage = $bal->{'ram_usage'};
                        
            $sth_inslastres->execute($account,
                                     $block_num, $block_time, $tx,
                                     $cpuw, $netw, $quota, $usage,
                                     $block_num, $block_time, $tx,
                                     $cpuw, $netw, $quota, $usage);
        }
        
        foreach my $bal (@{$action->{'currency_balances'}})
        {
            my $account = $bal->{'account_name'};
            my $contract = $bal->{'contract'};
            my ($amount, $currency) = split(/\s+/, $bal->{'balance'});

            $sth_checkcurrblock->execute($account, $contract, $currency);
            my $r = $sth_checkcurrblock->fetchall_arrayref();
            if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num )
            {
                next;
            }
            
            $sth_inslastcurr->execute($account,
                                      $block_num, $block_time, $tx,
                                      $contract,
                                      $currency,
                                      $amount,
                                      $block_num, $block_time, $tx,
                                      $amount);
        }

        my $act = $action->{'action_trace'}{'act'};
        
        $sth_checkcontract->execute($act->{'account'}, $act->{'name'});
        my $r = $sth_checkcontract->fetchall_arrayref();
        if( scalar(@{$r}) == 0 or $r->[0][0] < $block_num )
        {
            $sth_inscontract->execute($act->{'account'}, $act->{'name'},
                                      $block_num, $block_time, $tx,
                                      $block_num, $block_time, $tx);
        }
    }

    $uncommitted++;
    if( $uncommitted >= $commit_every )
    {
        $dbh->commit();
        $uncommitted = 0;
    }
}


print STDERR "The stream ended\n";
$dbh->disconnect();



