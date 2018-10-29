use strict;
use warnings;
use ZMQ::Raw;
use JSON;
use Getopt::Long;
use DBI;

$| = 1;

my $ep_pull;
my $ep_sub;

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


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
                        mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbh;

my $sth_check_res_block = $dbh->prepare
    ('SELECT block_num FROM LIGHTAPI_LATEST_RESOURCE ' .
     'WHERE account_name=?');

my $sth_ins_last_res = $dbh->prepare
    ('INSERT INTO LIGHTAPI_LATEST_RESOURCE ' . 
     '(account_name, block_num, block_time, trx_id, ' .
     'cpu_weight, net_weight, ram_quota, ram_usage) ' .
     'VALUES(?,?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, ' .
     'cpu_weight=?, net_weight=?, ram_quota=?, ram_usage=?');


my $sth_check_curr_block = $dbh->prepare
    ('SELECT block_num FROM LIGHTAPI_LATEST_CURRENCY ' .
     'WHERE account_name=? AND contract=? AND currency=?');


my $sth_ins_last_curr = $dbh->prepare
    ('INSERT INTO LIGHTAPI_LATEST_CURRENCY ' . 
     '(account_name, block_num, block_time, trx_id, contract, currency, amount) ' .
     'VALUES(?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, amount=?');


my $sth_check_auth_block = $dbh->prepare
    ('SELECT block_num FROM LIGHTAPI_AUTH_THRESHOLDS ' .
     'WHERE account_name=? AND perm=?');

my $sth_ins_auth_thres = $dbh->prepare
    ('INSERT INTO LIGHTAPI_AUTH_THRESHOLDS ' . 
     '(account_name, perm, threshold, parent, block_num, block_time, trx_id) ' .
     'VALUES(?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE threshold=?, parent=?,block_num=?, block_time=?, trx_id=?');

my $sth_del_auth_keys = $dbh->prepare
    ('DELETE FROM LIGHTAPI_AUTH_KEYS WHERE account_name=? AND perm=?');

my $sth_del_auth_acc = $dbh->prepare
    ('DELETE FROM LIGHTAPI_AUTH_ACC WHERE account_name=? AND perm=?');

my $sth_ins_auth_key = $dbh->prepare
    ('INSERT INTO LIGHTAPI_AUTH_KEYS ' . 
     '(account_name, perm, pubkey, weight) ' .
     'VALUES(?,?,?,?)');

my $sth_ins_auth_acc = $dbh->prepare
    ('INSERT INTO LIGHTAPI_AUTH_ACC ' . 
     '(account_name, perm, actor, permission, weight) ' .
     'VALUES(?,?,?,?,?)');



my $ctxt = ZMQ::Raw::Context->new;
my $socket;
my $connectstr;

if( defined($ep_pull) )
{
    $connectstr = $ep_pull;
    $socket = ZMQ::Raw::Socket->new ($ctxt, ZMQ::Raw->ZMQ_PULL );
    $socket->setsockopt(ZMQ::Raw::Socket->ZMQ_RCVBUF, 10240);
    $socket->connect( $connectstr );
}
else
{
    $connectstr = $ep_sub;
    $socket = ZMQ::Raw::Socket->new ($ctxt, ZMQ::Raw->ZMQ_SUB );
    $socket->setsockopt(ZMQ::Raw::Socket->ZMQ_RCVBUF, 10240);
    # subscribe only on action events
    $socket->setsockopt(ZMQ::Raw::Socket->ZMQ_SUBSCRIBE, pack('VV', 0, 0));
    $socket->connect( $connectstr );
}    


my $sighandler = sub {
    print STDERR ("Disconnecting the ZMQ socket\n");
    $socket->disconnect($connectstr);
    $socket->close();
    print STDERR ("Finished\n");
    exit;
};

$SIG{'HUP'} = $sighandler;
$SIG{'TERM'} = $sighandler;
$SIG{'INT'} = $sighandler;


my $json = JSON->new->pretty->canonical;

while(1)
{
    my $data = $socket->recv();
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
            
            $sth_check_res_block->execute($account);
            my $r = $sth_check_res_block->fetchall_arrayref();
            if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num )
            {
                next;
            }
            
            my $cpuw = $bal->{'cpu_weight'}/10000.0;            
            my $netw = $bal->{'net_weight'}/10000.0;
            my $quota = $bal->{'ram_quota'};
            my $usage = $bal->{'ram_usage'};
                        
            $sth_ins_last_res->execute
                ($account, $block_num, $block_time, $tx,
                 $cpuw, $netw, $quota, $usage,
                 $block_num, $block_time, $tx,
                 $cpuw, $netw, $quota, $usage);
        }
        
        foreach my $bal (@{$action->{'currency_balances'}})
        {
            my $account = $bal->{'account_name'};
            my $contract = $bal->{'contract'};
            my ($amount, $currency) = split(/\s+/, $bal->{'balance'});

            $sth_check_curr_block->execute($account, $contract, $currency);
            my $r = $sth_check_curr_block->fetchall_arrayref();
            if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num )
            {
                next;
            }
            
            $sth_ins_last_curr->execute
                ($account, $block_num, $block_time, $tx,
                 $contract, $currency, $amount,
                 $block_num, $block_time, $tx, $amount);
        }

        my $atrace = $action->{'action_trace'};
        my $state = {'auth' => []};
        process_trace($atrace, $state);

        foreach my $authdata (@{$state->{'auth'}})
        {
            my $account = $authdata->{'account'};
            my $perm = $authdata->{'permission'};

            $sth_check_auth_block->execute($account, $perm);
            my $r = $sth_check_auth_block->fetchall_arrayref();
            if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num )
            {
                next;
            }

            my $threshold = $authdata->{'auth'}{'threshold'};
            my $parent = $authdata->{'parent'};

            $sth_ins_auth_thres->execute
                ($account, $perm, $threshold, $parent,
                 $block_num, $block_time, $tx,
                 $threshold, $parent, $block_num, $block_time, $tx);

            $sth_del_auth_keys->execute($account, $perm);
            $sth_del_auth_acc->execute($account, $perm);

            foreach my $keydata (@{$authdata->{'auth'}{'keys'}})
            {
                $sth_ins_auth_key->execute
                    ($account, $perm, $keydata->{'key'}, $keydata->{'weight'});
            }
            
            foreach my $accdata (@{$authdata->{'auth'}{'accounts'}})
            {
                $sth_ins_auth_acc->execute
                    ($account, $perm, $accdata->{'permission'}{'actor'},
                     $accdata->{'permission'}{'permission'},
                     $accdata->{'weight'});
            }            
        }
    }

    $dbh->commit();
}


print STDERR "The stream ended\n";
$dbh->disconnect();



sub process_trace
{
    my $atrace = shift;
    my $state = shift;

    my $gseq = $atrace->{'receipt'}{'global_sequence'};
    if( not defined($state->{'seqs'}{$gseq}) )
    {
        $state->{'seqs'}{$gseq} = 1;
        my $act = $atrace->{'act'};

        if( $atrace->{'receipt'}{'receiver'} eq 'eosio' and $act->{'account'} eq 'eosio' )
        {
            my $aname = $act->{'name'};
            my $data = $act->{'data'};

            if( ref($data) eq 'HASH' and $aname eq 'updateauth' )
            {
                push(@{$state->{'auth'}}, $data);
            }
        }
    }

    if( defined($atrace->{'inline_traces'}) )
    {
        foreach my $trace (@{$atrace->{'inline_traces'}})
        {
            process_trace($trace, $state);
        }
    }
}


