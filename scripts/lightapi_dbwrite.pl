use strict;
use warnings;
use ZMQ::Raw;
use JSON;
use Getopt::Long;
use DBI;

$| = 1;

my $network;
my $ep_pull;
my $ep_sub;

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


my $ok = GetOptions
    ('network=s' => \$network,
     'pull=s'    => \$ep_pull,
     'sub=s'     => \$ep_sub,
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or not $network or
    (not $ep_pull and not $ep_sub) or
    ($ep_pull and $ep_sub) )
{
    print STDERR "Usage: $0 --network=eos [options...]\n",
    "The utility connects to EOS ZMQ PUB or PUSH socket and \n",
    "updates the database\n",
    "Options:\n",
    "  --network=NAME     name of EOS network\n",
    "  --pull=ENDPOINT    connect to a PUSH socket\n",
    "  --sub=ENDPOINT     connect to a PUB socket\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

our $db;



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
    $socket->setsockopt(ZMQ::Raw::Socket->ZMQ_SUBSCRIBE, '');
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

    my $ok = 0;
    while( not $ok )
    {
        eval {
            getdb();
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
                    
                    $db->{'sth_check_res_block'}->execute($network, $account);
                    my $r = $db->{'sth_check_res_block'}->fetchall_arrayref();
                    if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num and $r->[0][1] )
                    {
                        next;
                    }
                    
                    my $cpuw = $bal->{'cpu_weight'};
                    my $netw = $bal->{'net_weight'};
                    my $quota = $bal->{'ram_quota'};
                    my $usage = $bal->{'ram_usage'};
                    
                    $db->{'sth_ins_last_res'}->execute
                        ($network, $account, $block_num, $block_time, $tx,
                         $cpuw, $netw, $quota, $usage,
                         $block_num, $block_time, $tx,
                         $cpuw, $netw, $quota, $usage);
                }
                
                foreach my $bal (@{$action->{'currency_balances'}})
                {
                    my $account = $bal->{'account_name'};
                    my $contract = $bal->{'contract'};
                    my ($amount, $currency) = split(/\s+/, $bal->{'balance'});

                    $db->{'sth_check_curr_block'}->execute($network, $account, $contract, $currency);
                    my $r = $db->{'sth_check_curr_block'}->fetchall_arrayref();
                    if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num and $r->[0][1] )
                    {
                        next;
                    }

                    my $decimals;
                    if( scalar(@{$r}) > 0 )
                    {
                        $decimals = $r->[0][2];
                    }
                    else
                    {
                        my $pos = index($amount, '.');
                        if( $pos == -1 )
                        {
                            $decimals = 0;
                        }
                        else
                        {
                            $decimals = length($amount) - $pos - 1;
                        }
                    }
                    
                    $db->{'sth_ins_last_curr'}->execute
                        ($network, $account, $block_num, $block_time, $tx,
                         $contract, $currency, $amount, $decimals,
                         $block_num, $block_time, $tx, $amount);
                }

                my $atrace = $action->{'action_trace'};
                my $state = {'addauth' => [], 'delauth' => []};
                process_trace($atrace, $state);

                foreach my $authdata (@{$state->{'delauth'}})
                {
                    my $account = $authdata->{'account'};
                    my $perm = $authdata->{'perm'};
                    
                    $db->{'sth_check_auth_block'}->execute($network, $account, $perm);
                    my $r = $db->{'sth_check_auth_block'}->fetchall_arrayref();
                    if( scalar(@{$r}) == 0 or ($r->[0][0] >= $block_num and $r->[0][1]) )
                    {
                        next;
                    }
                    
                    $db->{'sth_del_auth_thres'}->execute($network, $account, $perm);
                    $db->{'sth_del_auth_keys'}->execute($network, $account, $perm);
                    $db->{'sth_del_auth_acc'}->execute($network, $account, $perm);
                }
                
                foreach my $authdata (@{$state->{'addauth'}})
                {
                    my $account = $authdata->{'account'};
                    my $perm = $authdata->{'perm'};
                    
                    $db->{'sth_check_auth_block'}->execute($network, $account, $perm);
                    my $r = $db->{'sth_check_auth_block'}->fetchall_arrayref();
                    if( scalar(@{$r}) > 0 and $r->[0][0] >= $block_num and $r->[0][1] )
                    {
                        next;
                    }

                    my $auth = $authdata->{'auth'};
                    my $threshold = $auth->{'threshold'};

                    $db->{'sth_ins_auth_thres'}->execute
                        ($network, $account, $perm, $threshold, 
                         $block_num, $block_time, $tx,
                         $threshold, $block_num, $block_time, $tx);
                    
                    $db->{'sth_del_auth_keys'}->execute($network, $account, $perm);
                    $db->{'sth_del_auth_acc'}->execute($network, $account, $perm);

                    foreach my $keydata (@{$auth->{'keys'}})
                    {
                        $db->{'sth_ins_auth_key'}->execute
                            ($network, $account, $perm, $keydata->{'key'}, $keydata->{'weight'});
                    }
                    
                    foreach my $accdata (@{$auth->{'accounts'}})
                    {
                        $db->{'sth_ins_auth_acc'}->execute
                            ($network, $account, $perm, $accdata->{'permission'}{'actor'},
                             $accdata->{'permission'}{'permission'},
                             $accdata->{'weight'});
                    }            
                }
            }
            elsif( $msgtype == 1 )  # irreversible block
            {
                my $data = $json->decode($js);
                my $block_num = $data->{'irreversible_block_num'};

                $db->{'sth_upd_irrev_res'}->execute($block_num);
                $db->{'sth_upd_irrev_curr'}->execute($block_num);
                $db->{'sth_upd_irrev_auth'}->execute($block_num);
            }

            $db->{'dbh'}->commit();
        };

        if( $@ )
        {
            print STDERR $@, "\n";
            sleep 3;
        }
        else
        {
            $ok = 1;
        }
    }
}


print STDERR "The stream ended\n";

if( defined($db->{'dbh'}) )
{
    $db->{'dbh'}->disconnect();
}





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

            if( ref($data) eq 'HASH' )
            {
                if( $aname eq 'newaccount' )
                {
                    push(@{$state->{'addauth'}},
                         {
                             'account' => $data->{'name'},
                             'perm' => 'owner',
                             'auth' => $data->{'owner'},
                         });
                    push(@{$state->{'addauth'}},
                         {
                             'account' => $data->{'name'},
                             'perm' => 'active',
                             'auth' => $data->{'active'},
                         });
                }
                elsif( $aname eq 'updateauth' )
                {
                    push(@{$state->{'addauth'}},
                         {
                             'account' => $data->{'account'},
                             'perm' => $data->{'permission'},
                             'auth' => $data->{'auth'},
                         });
                }
                elsif( $aname eq 'deleteauth' )
                {
                    push(@{$state->{'delauth'}},
                         {
                             'account' => $data->{'account'},
                             'perm' => $data->{'permission'},
                         });
                }
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


sub getdb
{
    if( defined($db) and $db->{'dbh'}->ping() )
    {
        return;
    }

    my $dbh = $db->{'dbh'} = DBI->connect($dsn, $db_user, $db_password,
                                          {'RaiseError' => 1, AutoCommit => 0,
                                           mariadb_server_prepare => 1});
    die($DBI::errstr) unless $dbh;

    $db->{'sth_check_res_block'} = $dbh->prepare
        ('SELECT block_num, irreversible FROM LIGHTAPI_LATEST_RESOURCE ' .
         'WHERE network=? AND account_name=?');
    
    $db->{'sth_ins_last_res'} = $dbh->prepare
        ('INSERT INTO LIGHTAPI_LATEST_RESOURCE ' . 
         '(network, account_name, block_num, block_time, trx_id, ' .
         'cpu_weight, net_weight, ram_quota, ram_usage) ' .
         'VALUES(?,?,?,?,?,?,?,?,?) ' .
         'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, ' .
         'cpu_weight=?, net_weight=?, ram_quota=?, ram_usage=?');


    $db->{'sth_check_curr_block'} = $dbh->prepare
        ('SELECT block_num, irreversible, decimals FROM LIGHTAPI_LATEST_CURRENCY ' .
         'WHERE network=? AND account_name=? AND contract=? AND currency=?');
    

    $db->{'sth_ins_last_curr'} = $dbh->prepare
        ('INSERT INTO LIGHTAPI_LATEST_CURRENCY ' . 
         '(network, account_name, block_num, block_time, trx_id, contract, currency, amount, decimals) ' .
         'VALUES(?,?,?,?,?,?,?,?,?) ' .
         'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, amount=?');


    $db->{'sth_check_auth_block'} = $dbh->prepare
        ('SELECT block_num, irreversible FROM LIGHTAPI_AUTH_THRESHOLDS ' .
         'WHERE network=? AND account_name=? AND perm=?');
    
    $db->{'sth_ins_auth_thres'} = $dbh->prepare
        ('INSERT INTO LIGHTAPI_AUTH_THRESHOLDS ' . 
         '(network, account_name, perm, threshold, block_num, block_time, trx_id) ' .
         'VALUES(?,?,?,?,?,?,?) ' .
         'ON DUPLICATE KEY UPDATE threshold=?, block_num=?, block_time=?, trx_id=?');

    $db->{'sth_del_auth_thres'} = $dbh->prepare
        ('DELETE FROM LIGHTAPI_AUTH_THRESHOLDS WHERE network=? AND account_name=? AND perm=?');

    $db->{'sth_del_auth_keys'} = $dbh->prepare
        ('DELETE FROM LIGHTAPI_AUTH_KEYS WHERE network=? AND account_name=? AND perm=?');

    $db->{'sth_del_auth_acc'} = $dbh->prepare
        ('DELETE FROM LIGHTAPI_AUTH_ACC WHERE network=? AND account_name=? AND perm=?');

    $db->{'sth_ins_auth_key'} = $dbh->prepare
        ('INSERT INTO LIGHTAPI_AUTH_KEYS ' . 
         '(network, account_name, perm, pubkey, weight) ' .
         'VALUES(?,?,?,?,?)');

    $db->{'sth_ins_auth_acc'} = $dbh->prepare
        ('INSERT INTO LIGHTAPI_AUTH_ACC ' . 
         '(network, account_name, perm, actor, permission, weight) ' .
         'VALUES(?,?,?,?,?,?)');

    $db->{'sth_upd_irrev_res'} = $dbh->prepare
        ('UPDATE LIGHTAPI_LATEST_RESOURCE SET irreversible=1 WHERE irreversible=0 AND block_num<=?');

    $db->{'sth_upd_irrev_curr'} = $dbh->prepare
        ('UPDATE LIGHTAPI_LATEST_CURRENCY SET irreversible=1 WHERE irreversible=0 AND block_num<=?');

    $db->{'sth_upd_irrev_auth'} = $dbh->prepare
        ('UPDATE LIGHTAPI_AUTH_THRESHOLDS SET irreversible=1 WHERE irreversible=0 AND block_num<=?');
}
