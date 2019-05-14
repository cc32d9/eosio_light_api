use strict;
use warnings;
use JSON;
use Getopt::Long;
use DBI;
use Net::WebSocket::Server;
use Protocol::WebSocket::Frame;

$Protocol::WebSocket::Frame::MAX_PAYLOAD_SIZE = 100*1024*1024;
$Protocol::WebSocket::Frame::MAX_FRAGMENTS_AMOUNT = 102400;

$| = 1;

my $port = 8800;
my $ack_every = 120;

my $network;

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


my $ok = GetOptions
    ('network=s' => \$network,
     'port=i'    => \$port,
     'ack=i'     => \$ack_every,     
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or not $network )
{
    print STDERR "Usage: $0 --network=eos [options...]\n",
    "The utility opens a WS port for Chronicle to send data to.\n",
    "Options:\n",
    "  --port=N           \[$port\] TCP port to listen to websocket connection\n",
    "  --ack=N            \[$ack_every\] Send acknowledgements every N blocks\n",
    "  --network=NAME     name of EOS network\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

our $db;
my $json = JSON->new;

my $confirmed_block = 0;
my $unconfirmed_block = 0;
my $irreversible = 0;

getdb();
{
    my $sth = $db->{'dbh'}->prepare
        ('SELECT block_num, irreversible FROM SYNC WHERE network=?');
    $sth->execute($network);
    my $r = $sth->fetchall_arrayref();
    if( scalar(@{$r}) > 0 )
    {
        $confirmed_block = $r->[0][0];
        $irreversible = $r->[0][1];
    }
}


Net::WebSocket::Server->new(
    listen => $port,
    on_connect => sub {
        my ($serv, $conn) = @_;
        $conn->on(
            'binary' => sub {
                my ($conn, $msg) = @_;
                my ($msgtype, $opts, $js) = unpack('VVa*', $msg);
                my $data = eval {$json->decode($js)};
                if( $@ )
                {
                    print STDERR $@, "\n\n";
                    print STDERR $js, "\n";
                    exit;
                } 
                
                my $ack = process_data($msgtype, $data, \$js);
                if( $ack > 0 )
                {
                    $conn->send_binary(sprintf("%d", $ack));
                    print STDERR "ack $ack\n";
                }
            },
            'disconnect' => sub {
                if( defined($db->{'dbh'}) )
                {
                    $db->{'dbh'}->disconnect();
                }
                print STDERR "Disconnected\n";
            },
            
            );
    },
    )->start;


sub process_data
{
    my $msgtype = shift;
    my $data = shift;
    my $jsptr = shift;

    if( $msgtype == 1001 ) # CHRONICLE_MSGTYPE_FORK
    {
        my $block_num = $data->{'block_num'};
        print STDERR "fork at $block_num\n";

        $db->{'sth_fork_sync'}->execute($block_num, $network);
        $db->{'sth_fork_currency'}->execute($network, $block_num);
        $db->{'sth_fork_auth_thresholds'}->execute($network, $block_num);
        $db->{'sth_fork_auth_keys'}->execute($network, $block_num);
        $db->{'sth_fork_auth_acc'}->execute($network, $block_num);
        $db->{'sth_fork_delband'}->execute($network, $block_num);
        $db->{'sth_fork_codehash'}->execute($network, $block_num);
        $db->{'dbh'}->commit();
        $confirmed_block = $block_num;
        $unconfirmed_block = 0;
        return $block_num;
    }
    elsif( $msgtype == 1003 ) # CHRONICLE_MSGTYPE_TX_TRACE
    {
        my $trace = $data->{'trace'};
        if( $trace->{'status'} eq 'executed' )
        {
            my $block_num = $data->{'block_num'};
            my $block_time = $data->{'block_timestamp'};
            $block_time =~ s/T/ /;
            
            my $state = {'addauth' => [], 'delauth' => []};
            foreach my $atrace ( @{$trace->{'action_traces'}} )
            {
                my $act = $atrace->{'act'};
                
                if( $atrace->{'receipt'}{'receiver'} eq 'eosio' and $act->{'account'} eq 'eosio' )
                {
                    my $aname = $act->{'name'};
                    my $data = $act->{'data'};
                    
                    if( ref($data) eq 'HASH' )
                    {
                        if( $aname eq 'newaccount' )
                        {
                            my $name = $data->{'name'};
                            if( not defined($name) )
                            {
                                # workaround for https://github.com/EOSIO/eosio.contracts/pull/129
                                $name = $data->{'newact'};
                            }
                            
                            push(@{$state->{'addauth'}},
                                 {
                                     'account' => $name,
                                     'perm' => 'owner',
                                     'auth' => $data->{'owner'},
                                 });
                            push(@{$state->{'addauth'}},
                                 {
                                     'account' => $name,
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
                        elsif( $aname eq 'delegatebw' )
                        {
                            my ($cpu, $curr1) = split(/\s/, $data->{'stake_cpu_quantity'});
                            my ($net, $curr2) = split(/\s/, $data->{'stake_net_quantity'});
                            
                            $db->{'sth_upd_delband'}->execute
                                ($network, $data->{'receiver'}, $block_num, $block_time,
                                 $data->{'from'}, $cpu, $net, 0);
                        }
                        elsif( $aname eq 'undelegatebw' )
                        {
                            my ($cpu, $curr1) = split(/\s/, $data->{'unstake_cpu_quantity'});
                            my ($net, $curr2) = split(/\s/, $data->{'unstake_net_quantity'});
                            
                            $db->{'sth_upd_delband'}->execute
                                ($network, $data->{'receiver'}, $block_num, $block_time,
                                 $data->{'from'}, $cpu, $net, 1);
                        }
                    }
                }
            }

            foreach my $authdata (@{$state->{'delauth'}})
            {
                my $account = $authdata->{'account'};
                my $perm = $authdata->{'perm'};
                                
                $db->{'sth_upd_auth_thres'}->execute
                    ($network, $account, $perm, $threshold, 
                     $block_num, $block_time, 1);
                $db->{'sth_upd_auth_keys'}->execute
                    ($network, $account, $perm, '', 0, $block_num, 1);
                $db->{'sth_upd_auth_acc'}->execute
                    ($network, $account, $perm, '', '', 0, $block_num, 1);
            }
            
            foreach my $authdata (@{$state->{'addauth'}})
            {
                my $account = $authdata->{'account'};
                my $perm = $authdata->{'perm'};
                my $auth = $authdata->{'auth'};
                my $threshold = $auth->{'threshold'};

                $db->{'sth_upd_auth_thres'}->execute
                    ($network, $account, $perm, $threshold, 
                     $block_num, $block_time, 0);

                # delete old keys and accounts, and add new ones
                
                $db->{'sth_upd_auth_keys'}->execute
                    ($network, $account, $perm, '', 0, $block_num, 1);
                $db->{'sth_upd_auth_acc'}->execute
                    ($network, $account, $perm, '', '', 0, $block_num, 1);

                foreach my $keydata (@{$auth->{'keys'}})
                {
                    $db->{'sth_upd_auth_key'}->execute
                        ($network, $account, $perm, $keydata->{'key'}, $keydata->{'weight'},
                         $block_num, 0);
                }
                    
                foreach my $accdata (@{$auth->{'accounts'}})
                {
                    $db->{'sth_upd_auth_acc'}->execute
                        ($network, $account, $perm, $accdata->{'permission'}{'actor'},
                         $accdata->{'permission'}{'permission'}, $accdata->{'weight'},
                         $block_num, 0);
                }
            }
        }
    }
    elsif( $msgtype == 1009 ) # CHRONICLE_MSGTYPE_RCVR_PAUSE
    {
        if( $unconfirmed_block > $confirmed_block )
        {
            $confirmed_block = $unconfirmed_block;
            return $confirmed_block;
        }
    }
    elsif( $msgtype == 1010 ) # CHRONICLE_MSGTYPE_BLOCK_COMPLETED
    {
        my $block_num = $data->{'block_num'};
        my $block_time = $data->{'block_timestamp'};
        $block_time =~ s/T/ /;
        $db->{'sth_upd_sync_head'}->execute($block_num, $block_time, $network);
        $db->{'dbh'}->commit();
        
        my $last_irreversible = $data->{'last_irreversible'};
        if( $last_irreversible > $irreversible )
        {
            $db->{'sth_get_upd_currency'}->execute($network, $last_irreversible);
            while(my $r = $db->{'sth_get_upd_currency'}->fetchrow_hashref('NAME_lc'))
            {
                if( $r->{'deleted'} )
                {
                    $db->{'sth_erase_currency'}->execute
                        ($network, map {$r->{$_}} qw(account_name contract currency));
                }
                else
                {
                    $db->{'sth_save_currency'}->execute
                        ($network, map {$r->{$_}}
                         qw(account_name block_num block_time contract currency amount decimals));
                }
            }
            $db->{'sth_del_upd_currency'}->execute($network, $last_irreversible);

        }
            

        $unconfirmed_block = $block_num;
        if( $unconfirmed_block - $confirmed_block >= $ack_every )
        {
            $confirmed_block = $unconfirmed_block;
            return $confirmed_block;
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

    $db->{'sth_fork_sync'} = $dbh->prepare
        ('UPDATE SYNC SET block_num=? WHERE network = ?');

    $db->{'sth_fork_currency'} = $dbh->prepare
        ('DELETE FROM UPD_CURRENCY_BAL WHERE network = ? AND block_num >= ? ');

    $db->{'sth_fork_auth_thresholds'} = $dbh->prepare
        ('DELETE FROM UPD_AUTH_THRESHOLDS WHERE network = ? AND block_num >= ? ');

    $db->{'sth_fork_auth_keys'} = $dbh->prepare
        ('DELETE FROM UPD_AUTH_KEYS WHERE network = ? AND block_num >= ? ');

    $db->{'sth_fork_auth_acc'} = $dbh->prepare
        ('DELETE FROM UPD_AUTH_ACC WHERE network = ? AND block_num >= ? ');

    $db->{'sth_fork_delband'} = $dbh->prepare
        ('DELETE FROM UPD_DELBAND WHERE network = ? AND block_num >= ? ');

    $db->{'sth_fork_codehash'} = $dbh->prepare
        ('DELETE FROM UPD_CODEHASH WHERE network = ? AND block_num >= ? ');


    $db->{'sth_upd_auth_thres'} = $dbh->prepare
        ('INSERT INTO UPD_AUTH_THRESHOLDS ' . 
         '(network, account_name, perm, threshold, block_num, block_time, deleted) ' .
         'VALUES(?,?,?,?,?,?,?)');

    $db->{'sth_upd_auth_keys'} = $dbh->prepare
        ('INSERT INTO UPD_AUTH_KEYS ' . 
         '(network, account_name, perm, pubkey, weight, block_num, deleted) ' .
         'VALUES(?,?,?,?,?,?,?)');

    $db->{'sth_ins_auth_acc'} = $dbh->prepare
        ('INSERT INTO UPD_AUTH_ACC ' . 
         '(network, account_name, perm, actor, permission, weight, block_num, deleted) ' .
         'VALUES(?,?,?,?,?,?,?,?)');

    $db->{'sth_upd_delband'} = $dbh->prepare
        ('INSERT INTO UPD_DELBAND ' . 
         '(network, account_name, block_num, block_time, del_from, cpu_weight, net_weight, deleted) ' .
         'VALUES(?,?,?,?,?,?,?,?)');

    $db->{'sth_upd_sync_head'} = $dbh->prepare
        ('UPDATE SYNC SET block_num=?, block_time=? WHERE network = ?');


    $db->{'sth_get_upd_currency'} = $dbh->prepare
        ('SELECT account_name, block_num, block_time, contract, currency, amount, decimals, deleted ' .
         'FROM UPD_CURRENCY_BAL WHERE network = ? AND block_num <= ? ORDER BY id');
    
    $db->{'sth_save_currency'} = $dbh->prepare
        ('INSERT INTO CURRENCY_BAL ' .
         '(network, account_name, block_num, block_time, contract, currency, amount, decimals) ' .
         'VALUES(?,?,?,?,?,?,?,?)');
    
    $db->{'sth_erase_currency'} = $dbh->prepare
        ('DELETE FROM CURRENCY_BAL WHERE ' .
         'network=? and account_name=? and contract=?, currency=?');
    
    $db->{'sth_del_upd_currency'} = $dbh->prepare
        ('DELETE FROM UPD_CURRENCY_BAL WHERE network = ? AND block_num <= ?');
}
