use strict;
use warnings;
use JSON;
use DBI;
use Math::BigInt;
use Math::BigFloat;
use Crypt::Digest::RIPEMD160 qw(ripemd160 ripemd160_hex);
use DateTime;
use DateTime::Format::ISO8601;
use Plack::Builder;
use Plack::Request;

# Need to make this configurable in an external file
my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapiro';
my $db_password = 'lightapiro';

my $dbh;

my $sth_getnet;
my $sth_sync;
my $sth_all_sync;

my $json = JSON->new();
my $jsonp = JSON->new()->pretty->canonical;


sub error
{
    my $req = shift;
    my $msg = shift;
    my $res = $req->new_response(400);
    $res->content_type('text/plain');
    $res->body($msg . "\x0d\x0a");
    return $res->finalize;
}


sub check_dbserver
{
    if ( not defined($dbh) or not $dbh->ping() ) {
        $dbh = DBI->connect($dsn, $db_user, $db_password,
                            {'RaiseError' => 1, AutoCommit => 1,
                             'mariadb_server_prepare' => 1});
        die($DBI::errstr) unless $dbh;

        $sth_getnet = $dbh->prepare
            ('SELECT NETWORKS.network, chainid, description, systoken, decimals, production, rex_enabled, ' .
             'TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) as sync, ' .
             'block_num, block_time ' .
             'FROM NETWORKS JOIN SYNC ON NETWORKS.network=SYNC.network WHERE NETWORKS.network=?');

        $sth_sync = $dbh->prepare
            ('SELECT TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) ' .
             'FROM SYNC WHERE network=?');

        $sth_all_sync = $dbh->prepare
            ('SELECT network, ' .
             'TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) as sync ' .
             'FROM SYNC');
    }
}




sub get_network
{
    my $name = shift;
    $sth_getnet->execute($name);
    my $r = $sth_getnet->fetchall_arrayref({});
    return $r->[0];
}


sub get_balances
{
    my $result = shift;
    my $network = shift;
    my $acc = shift;

    my $sth_bal = $dbh->prepare
            ('SELECT contract, currency, ' .
             'CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' .
             'FROM ' . $network . '_CURRENCY_BAL ' .
             'WHERE account_name=?');
    $sth_bal->execute($acc);
    my $balarray = $sth_bal->fetchall_arrayref({});
    my $balhash = {};
    foreach my $row (@{$balarray})
    {
        $row->{'amount'} = sprintf('%.'.$row->{'decimals'} . 'f', $row->{'amount'});
        $balhash->{$row->{'contract'}}{$row->{'currency'}} = $row;
    }

    my $sth_bal_upd = $dbh->prepare
            ('SELECT contract, currency, ' .
             'CAST(amount AS DECIMAL(48,24)) AS amount, decimals, deleted ' .
             'FROM ' . $network . '_UPD_CURRENCY_BAL ' .
             'WHERE account_name=? ORDER BY id');
    $sth_bal_upd->execute($acc);
    my $bal_upd = $sth_bal_upd->fetchall_arrayref({});
    foreach my $row (@{$bal_upd})
    {
        if( $row->{'deleted'} )
        {
            delete $balhash->{$row->{'contract'}}{$row->{'currency'}};
        }
        else
        {
            delete $row->{'deleted'};
            $row->{'amount'} = sprintf('%.'.$row->{'decimals'} . 'f', $row->{'amount'});
            $balhash->{$row->{'contract'}}{$row->{'currency'}} = $row;
        }
    }

    my $ret = [];
    foreach my $contract (sort keys %{$balhash})
    {
        foreach my $currency (sort keys %{$balhash->{$contract}})
        {
            push(@{$ret}, $balhash->{$contract}{$currency});
        }
    }

    $result->{'balances'} = $ret;
}



sub get_accinfo
{
    my $result = shift;
    my $network = shift;
    my $acc = shift;

    {
        my $sth_res = $dbh->prepare
            ('SELECT ' .
             'cpu_weight, net_weight, ' .
             'ram_bytes ' .
             'FROM ' . $network . '_USERRES ' .
             'WHERE account_name=?');
        $sth_res->execute($acc);
        $result->{'resources'} = $sth_res->fetchrow_hashref();

        my $sth_res_upd = $dbh->prepare
            ('SELECT ' .
             'cpu_weight, net_weight, ' .
             'ram_bytes, deleted ' .
             'FROM ' . $network . '_UPD_USERRES ' .
             'WHERE account_name=? ORDER BY id');
        $sth_res_upd->execute($acc);
        my $res_upd = $sth_res_upd->fetchall_arrayref({});
        foreach my $row (@{$res_upd}) {
            $result->{'resources'} = $row;
        }
    }
    {
        $result->{'permissions'} = get_permissions($network, $acc);

        my $sth_acc_auth_upd = $dbh->prepare
            ('SELECT perm, jsdata, deleted ' .
             'FROM ' . $network . '_UPD_AUTH WHERE account_name=? ORDER BY id');
        $sth_acc_auth_upd->execute($acc);
        my $auth_upd = $sth_acc_auth_upd->fetchall_arrayref({});
        foreach my $row (@{$auth_upd}) {
            my $newperms = [];
            foreach my $p (@{$result->{'permissions'}}) {
                if ( $p->{'perm'} ne $row->{'perm'} ) {
                    push(@{$newperms}, $p);
                }
            }

            if ( not $row->{'deleted'} ) {
                push(@{$newperms}, auth_upd_row_to_perm($row, $json->decode($row->{'jsdata'})));
            }

            $result->{'permissions'} = $newperms;
        }
    }
    {
        my $sth_linkauth = $dbh->prepare
            ('SELECT code, type, requirement ' .
             'FROM ' . $network . '_LINKAUTH ' .
             'WHERE account_name=?');
        $sth_linkauth->execute($acc);
        my $linkauth_rows = $sth_linkauth->fetchall_arrayref({});
        my %linkauth;
        foreach my $row (@{$linkauth_rows}) {
            $linkauth{$row->{'code'}}{$row->{'type'}} = $row;
        }

        my $sth_linkauth_upd = $dbh->prepare
            ('SELECT code, type, requirement, deleted ' .
             'FROM ' . $network . '_UPD_LINKAUTH ' .
             'WHERE account_name=? ORDER BY id');
        $sth_linkauth_upd->execute($acc);
        my $linkauth_upd = $sth_linkauth_upd->fetchall_arrayref({});
        foreach my $row (@{$linkauth_upd}) {
            if ( $row->{'deleted'} ) {
                delete $linkauth{$row->{'code'}}{$row->{'type'}};
            } else {
                delete $row->{'deleted'};
                $linkauth{$row->{'code'}}{$row->{'type'}} = $row;
            }
        }

        $result->{'linkauth'} = [];
        foreach my $code (sort keys %linkauth) {
            foreach my $type (sort keys %{$linkauth{$code}}) {
                push(@{$result->{'linkauth'}}, $linkauth{$code}{$type});
            }
        }
    }
    {
        my $sth_delegated_from = $dbh->prepare
            ('SELECT del_from, cpu_weight, net_weight ' .
             'FROM ' . $network . '_DELBAND ' .
             'WHERE account_name=?');

        $sth_delegated_from->execute($acc);
        my $delfrom = $sth_delegated_from->fetchall_hashref('del_from');

        my $sth_delegated_from_upd = $dbh->prepare
            ('SELECT del_from, cpu_weight, net_weight, deleted ' .
             'FROM ' . $network . '_UPD_DELBAND ' .
             'WHERE account_name=? ORDER BY id');
        $sth_delegated_from_upd->execute($acc);
        my $del_from_upd = $sth_delegated_from_upd->fetchall_arrayref({});
        foreach my $row (@{$del_from_upd}) {
            if ( $row->{'deleted'} ) {
                delete $delfrom->{$row->{'del_from'}};
            } else {
                delete $row->{'deleted'};
                $delfrom->{$row->{'del_from'}} = $row;
            }
        }

        $result->{'delegated_from'} = [];
        foreach my $name (sort keys %{$delfrom}) {
            push(@{$result->{'delegated_from'}}, $delfrom->{$name});
        }
    }
    {
        my $sth_delegated_to = $dbh->prepare
            ('SELECT account_name, cpu_weight, net_weight ' .
             'FROM ' . $network . '_DELBAND ' .
             'WHERE del_from=?');
        $sth_delegated_to->execute($acc);
        my $delto = $sth_delegated_to->fetchall_hashref('account_name');

        my $sth_delegated_to_upd = $dbh->prepare
            ('SELECT account_name, cpu_weight, net_weight, deleted ' .
             'FROM ' . $network . '_UPD_DELBAND ' .
             'WHERE del_from=? ORDER BY id');
        $sth_delegated_to_upd->execute($acc);
        my $del_to_upd = $sth_delegated_to_upd->fetchall_arrayref({});
        foreach my $row (@{$del_to_upd}) {
            if ( $row->{'deleted'} ) {
                delete $delto->{$row->{'account_name'}};
            } else {
                delete $row->{'deleted'};
                $delto->{$row->{'account_name'}} = $row;
            }
        }

        $result->{'delegated_to'} = [];
        foreach my $name (sort keys %{$delto}) {
            push(@{$result->{'delegated_to'}}, $delto->{$name});
        }
    }
    {
        my $sth_get_code = $dbh->prepare
            ('SELECT code_hash ' .
             'FROM ' . $network . '_CODEHASH ' .
             'WHERE account_name=?');
        $sth_get_code->execute($acc);
        my $r = $sth_get_code->fetchall_arrayref({});
        if ( scalar(@{$r}) > 0 ) {
            $result->{'code'} = $r->[0];
        }

        my $sth_get_code_upd = $dbh->prepare
            ('SELECT code_hash, deleted ' .
             'FROM ' . $network . '_UPD_CODEHASH ' .
             'WHERE account_name=? ORDER BY id');
        $sth_get_code_upd->execute($acc);
        my $code_upd = $sth_get_code_upd->fetchall_arrayref({});
        foreach my $row (@{$code_upd}) {
            if ( $row->{'deleted'} ) {
                delete $result->{'code'};
            } else {
                delete $row->{'deleted'};
                $result->{'code'} = $row;
            }
        }
    }
}



sub retrieve_rexinfo
{
    my $network = shift;
    my $acc = shift;

    my $ret = {};

    my $rexpool;

    {
        my $sth_rexpool = $dbh->prepare
            ('SELECT CAST(total_lent AS DECIMAL(48,24)) AS total_lent, ' .
             'CAST(total_unlent AS DECIMAL(48,24)) AS total_unlent, ' .
             'CAST(total_rent AS DECIMAL(48,24)) AS total_rent, ' .
             'CAST(total_lendable AS DECIMAL(48,24)) AS total_lendable, ' .
             'CAST(total_rex AS DECIMAL(48,24)) AS total_rex, ' .
             'CAST(namebid_proceeds AS DECIMAL(48,24)) AS namebid_proceeds, ' .
             'loan_num ' .
             'FROM ' . $network . '_REXPOOL');
        $sth_rexpool->execute();
        my $r = $sth_rexpool->fetchall_arrayref({});
        if ( scalar(@{$r}) == 0 ) {
            return;
        }
        $rexpool = $r->[0];

        my $sth_rexpool_upd = $dbh->prepare
            ('SELECT CAST(total_lent AS DECIMAL(48,24)) AS total_lent, ' .
             'CAST(total_unlent AS DECIMAL(48,24)) AS total_unlent, ' .
             'CAST(total_rent AS DECIMAL(48,24)) AS total_rent, ' .
             'CAST(total_lendable AS DECIMAL(48,24)) AS total_lendable, ' .
             'CAST(total_rex AS DECIMAL(48,24)) AS total_rex, ' .
             'CAST(namebid_proceeds AS DECIMAL(48,24)) AS namebid_proceeds, ' .
             'loan_num ' .
             'FROM ' . $network . '_UPD_REXPOOL ' .
             'ORDER BY id');
        $sth_rexpool_upd->execute();
        my $upd = $sth_rexpool_upd->fetchall_arrayref({});
        if( scalar(@{$upd}) > 0 ) {
            $rexpool = pop @{$upd};
        }
    }

    $ret->{'pool'} = $rexpool;

    my $rexfund = 0;

    {
        my $sth_rexfund = $dbh->prepare
            ('SELECT ' .
             'CAST(balance AS DECIMAL(48,24)) AS balance ' .
             'FROM ' . $network . '_REXFUND ' .
             'WHERE account_name=?');
        $sth_rexfund->execute($acc);
        my $r = $sth_rexfund->fetchall_arrayref({});
        if ( scalar(@{$r}) > 0 ) {
            $rexfund = $r->[0]{'balance'};
        }

        my $sth_rexfund_upd = $dbh->prepare
            ('SELECT ' .
             'CAST(balance AS DECIMAL(48,24)) AS balance, deleted ' .
             'FROM ' . $network . '_UPD_REXFUND ' .
             'WHERE account_name=? ORDER BY id');
        $sth_rexfund_upd->execute($acc);
        my $upd = $sth_rexfund_upd->fetchall_arrayref({});
        foreach my $row (@{$upd}) {
            if ( $row->{'deleted'} ) {
                $rexfund = 0;
            } else {
                $rexfund = $row->{'balance'};
            }
        }
    }

    $ret->{'fund'} = $rexfund;

    my $rexbal;
    {
        my $sth_rexbal = $dbh->prepare
            ('SELECT ' .
             'CAST(vote_stake AS DECIMAL(48,24)) AS vote_stake, ' .
             'CAST(rex_balance AS DECIMAL(48,24)) AS rex_balance, ' .
             'matured_rex, rex_maturities ' .
             'FROM ' . $network . '_REXBAL ' .
             'WHERE account_name=?');
        $sth_rexbal->execute($acc);
        my $r = $sth_rexbal->fetchall_arrayref({});
        if ( scalar(@{$r}) > 0 ) {
            $rexbal = $r->[0];
        }

        my $sth_rexbal_upd = $dbh->prepare
            ('SELECT ' .
             'CAST(vote_stake AS DECIMAL(48,24)) AS vote_stake, ' .
             'CAST(rex_balance AS DECIMAL(48,24)) AS rex_balance, ' .
             'matured_rex, rex_maturities, deleted ' .
             'FROM ' . $network . '_UPD_REXBAL ' .
             'WHERE account_name=? ORDER BY id');
        $sth_rexbal_upd->execute($acc);
        my $upd = $sth_rexbal_upd->fetchall_arrayref({});
        foreach my $row (@{$upd}) {
            if ( $row->{'deleted'} ) {
                $rexbal = undef;
            } else {
                $rexbal = $row;
            }
        }
    }

    if( defined($rexbal) ) {
        $ret->{'bal'}= {
                        'vote_stake' => $rexbal->{'vote_stake'},
                        'rex_balance' => $rexbal->{'rex_balance'},
                        'matured_rex' => $rexbal->{'matured_rex'},
                       };
        $ret->{'bal'}{'rex_maturities'} = $json->decode($rexbal->{'rex_maturities'});
    }

    return $ret;
}


sub get_rexbalances
{
    my $result = shift;
    my $network = shift;
    my $acc = shift;
    my $netinfo = shift;

    if( not $netinfo->{'rex_enabled'} ) {
        return;
    }

    my $decimals = $netinfo->{'decimals'};
    my $systoken = $netinfo->{'systoken'};

    my $rex = retrieve_rexinfo($network, $acc);

    $result->{'rex'}{'fund'} = sprintf('%.'.$decimals . 'f %s', $rex->{'fund'}, $systoken);

    my $maturing_rex = Math::BigFloat->new(0);
    my $matured_rex = Math::BigFloat->new(0);
    my $savings_rex = Math::BigFloat->new(0);
    my $vote_stake = 0;

    my $end_of_time = DateTime->from_epoch('epoch' => 0xffffffff, 'time_zone' => 'UTC');

    if( defined($rex->{'bal'}) ) {
        my $rexbal = $rex->{'bal'};
        $matured_rex += $rexbal->{'matured_rex'};
        $vote_stake = $rexbal->{'vote_stake'};

        my $now = DateTime->now('time_zone' => 'UTC');

        foreach my $enry (@{$rex->{'bal'}{'rex_maturities'}}) {
            my $key = $enry->{'key'};
            my $val = $enry->{'value'};
            if( not defined($key) ) {
                $key = $enry->{'first'};
                $val = $enry->{'second'};
            }
            next unless (defined($key) and defined($val));

            my $mt = DateTime::Format::ISO8601->parse_datetime($key);
            $mt->set_time_zone('UTC');

            if( DateTime->compare($mt, $now) <= 0 ) {
                $matured_rex += $val;
            }
            else {
                if( DateTime->compare($mt, $end_of_time) == 0 ) {
                    $savings_rex += $val;
                }
                else {
                    $maturing_rex += $val;
                }
            }
        }
    }

    my $rexprice = Math::BigFloat->new
        ($rex->{'pool'}{'total_lendable'})->bdiv($rex->{'pool'}->{'total_rex'})->bdiv(10000);

    $result->{'rex'}{'maturing'} = sprintf('%.'.$decimals . 'f %s',
                                           $maturing_rex*$rexprice, $systoken);

    $result->{'rex'}{'matured'} = sprintf('%.'.$decimals . 'f %s',
                                          $matured_rex*$rexprice, $systoken);

    $result->{'rex'}{'savings'} = sprintf('%.'.$decimals . 'f %s',
                                          $savings_rex*$rexprice, $systoken);
}



# stolen from Bitcoin::Crypto::Base58;

my @alphabet = qw(
    1 2 3 4 5 6 7 8 9
    A B C D E F G H J K L M N P Q R S T U V W X Y Z
    a b c d e f g h i j k m n o p q r s t u v w x y z
);

my %alphabet_mapped;

{
    my $i;
    for ($i = 0; $i < @alphabet; ++$i) {
        $alphabet_mapped{$alphabet[$i]} = $i;
    }
}

sub encode_base58
{
    my ($bytes) = @_;
    my $number = Math::BigInt->from_hex("0x" . unpack "H*", $bytes);
    my $result = "";
    my $size = scalar @alphabet;
    while ($number->is_pos()) {
        my $copy = $number->copy();
        $result = $alphabet[$copy->bmod($size)] . $result;
        $number->bdiv($size);
    }
    return $result;
}

sub decode_base58
{
    my ($base58encoded) = @_;
    my $result = Math::BigInt->new(0);
    my @arr = split "", $base58encoded;
    while (@arr > 0) {
        my $current = $alphabet_mapped{shift @arr};
        return undef unless defined $current;
        my $step = Math::BigInt->new(scalar @alphabet)->bpow(scalar @arr)->bmul($current);
        $result->badd($step);
    }
    return pack "H*", pad_hex($result->as_hex());
}

sub pad_hex
{
    my ($hex) = @_;
    $hex =~ s/^0x//;
    return "0" x (length($hex) % 2) . $hex;
}

sub from_legacy_key
{
    my $pubkey = shift;
    if( substr($pubkey, 0, 3) eq 'EOS' )
    {
        my $whole = decode_base58(substr($pubkey,3));
        my ($key, $checksum) = unpack('a[33]a[4]', $whole);
        if( substr(ripemd160_hex($key), 0, 8) ne unpack('H*', $checksum) )
        {
            return '##INVALID_KEY##';
        }

        return 'PUB_K1_' .
            encode_base58(pack('a[33]a[4]', $key, ripemd160(pack('a[33]a[2]', $key, 'K1'))));
    }
    return $pubkey;
}


sub to_legacy_key
{
    my $pubkey = shift;
    if( substr($pubkey, 0, 7) eq 'PUB_K1_' )
    {
        my $whole = decode_base58(substr($pubkey,7));
        my ($key, $checksum) = unpack('a[33]a[4]', $whole);
        if( substr(ripemd160_hex(pack('a[33]a[2]', $key, 'K1')), 0, 8) ne unpack('H*', $checksum) )
        {
            return '##INVALID_KEY##';
        }

        return 'EOS' . encode_base58(pack('a[33]a[4]', $key, ripemd160($key)));
    }
    return $pubkey;
}


sub get_permissions
{
    my $network = shift;
    my $acc = shift;

    my $sth_perms = $dbh->prepare
        ('SELECT perm, threshold ' .
         'FROM ' . $network . '_AUTH_THRESHOLDS ' .
         'WHERE account_name=?');

    my $sth_keys = $dbh->prepare
        ('SELECT pubkey, weight ' .
         'FROM ' . $network . '_AUTH_KEYS ' .
         'WHERE account_name=? AND perm=?');

    my $sth_authacc = $dbh->prepare
        ('SELECT actor, permission, weight ' .
         'FROM ' . $network . '_AUTH_ACC ' .
         'WHERE account_name=? AND perm=?');

    $sth_perms->execute($acc);
    my $perms = $sth_perms->fetchall_arrayref({});
    foreach my $permission (@{$perms}) {
        $sth_keys->execute($acc, $permission->{'perm'});
        $permission->{'auth'}{'keys'} = $sth_keys->fetchall_arrayref({});
        foreach my $row (@{$permission->{'auth'}{'keys'}})
        {
            my $newformat = $row->{'pubkey'};
            $row->{'pubkey'} = to_legacy_key($newformat);
            $row->{'public_key'} = $newformat;
        }

        $sth_authacc->execute($acc, $permission->{'perm'});
        $permission->{'auth'}{'accounts'} = $sth_authacc->fetchall_arrayref({});
    }
    return $perms;
}


sub get_authorized_accounts
{
    my $network = shift;
    my $acc = shift;
    my $permission = shift;
    my $accounts = shift;

    my $sth_acc_by_actor = $dbh->prepare
            ('SELECT account_name, perm ' .
             'FROM ' . $network . '_AUTH_ACC ' .
             'WHERE actor=? AND permission=? LIMIT 100');
    $sth_acc_by_actor->execute($acc, $permission);
    my $res = $sth_acc_by_actor->fetchall_arrayref({});

    foreach my $r (@{$res})
    {
        my $depacc = $r->{'account_name'};
        my $depperm = $r->{'perm'};
        if( not $accounts->{$network}{$depacc}{$depperm} )
        {
            $accounts->{$network}{$depacc}{$depperm} = 1;
            get_authorized_accounts($network, $depacc, $depperm, $accounts);
        }
    }
}


sub auth_upd_row_to_perm
{
    my $row = shift;
    my $auth = shift;

    my $ret = {};
    foreach my $attr ('perm')
    {
        $ret->{$attr} = $row->{$attr};
    }

    $ret->{'auth'} = {'keys' => [], 'accounts' => [], 'threshold' => $auth->{'threshold'}};

    foreach my $keydata (@{$auth->{'keys'}})
    {
        push(@{$ret->{'auth'}{'keys'}},
             {
              'pubkey' => to_legacy_key($keydata->{'key'}),
              'public_key' => $keydata->{'key'},
              'weight' => $keydata->{'weight'}
             });
    }

    foreach my $accdata (@{$auth->{'accounts'}})
    {
        push(@{$ret->{'auth'}{'accounts'}},
             {
              'actor' => $accdata->{'permission'}{'actor'},
              'permission' => $accdata->{'permission'}{'permission'},
              'weight' => $accdata->{'weight'}
             });
    }

    return $ret;
}



my $builder = Plack::Builder->new;

$builder->mount
    ('/api/networks' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);

         check_dbserver();
         my $sth_allnetworks = $dbh->prepare
             ('SELECT NETWORKS.network, chainid, description, systoken, decimals, production, ' .
              'TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) as sync, ' .
              'block_num, block_time ' .
              'FROM NETWORKS JOIN SYNC ON NETWORKS.network=SYNC.network');
         $sth_allnetworks->execute();
         my $result = $sth_allnetworks->fetchall_arrayref({});

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });

$builder->mount
    ('/api/account' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})$/ ) {
             return(error($req, 'Expected a network name and a valid EOS account name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};

         get_accinfo($result, $network, $acc);
         get_balances($result, $network, $acc);
         get_rexbalances($result, $network, $acc, $netinfo);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });


$builder->mount
    ('/api/accinfo' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})$/ ) {
             return(error($req, 'Expected a network name and a valid EOS account name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};

         get_accinfo($result, $network, $acc);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });



$builder->mount
    ('/api/balances' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})$/ ) {
             return(error($req, 'Expected a network name and a valid EOS account name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};
         get_balances($result, $network, $acc);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });



$builder->mount
    ('/api/rexbalance' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})$/ ) {
             return(error($req, 'Expected a network name and a valid EOS account name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};
         get_rexbalances($result, $network, $acc, $netinfo);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });

$builder->mount
    ('/api/rexraw' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})$/ ) {
             return(error($req, 'Expected a network name and a valid EOS account name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         if( not $netinfo->{'rex_enabled'} ) {
             return(error($req, 'REX is not enabled on ' . $network));
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};
         $result->{'rexraw'} = retrieve_rexinfo($network, $acc);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });


$builder->mount
    ('/api/tokenbalance' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})\/([a-z1-5.]{1,13})\/([A-Z]{1,7})$/ ) {
             return(error($req, 'Expected network name, account, contract, and token name in URL path'));
         }

         my $network = $1;
         my $acc = $2;
         my $contract = $3;
         my $currency = $4;
         check_dbserver();

         my $sth_tokenbal = $dbh->prepare
             ('SELECT CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' .
              'FROM ' . $network . '_CURRENCY_BAL ' .
              'WHERE account_name=? AND contract=? AND currency=?');
         $sth_tokenbal->execute($acc, $contract, $currency);
         my $r = $sth_tokenbal->fetchall_arrayref({});
         my $result = '0';
         if( scalar(@{$r}) > 0 )
         {
             $result = sprintf('%.'.$r->[0]{'decimals'} . 'f', $r->[0]{'amount'});
         }

         my $sth_tokenbal_upd = $dbh->prepare
             ('SELECT CAST(amount AS DECIMAL(48,24)) AS amount, decimals, deleted ' .
              'FROM ' . $network . '_UPD_CURRENCY_BAL ' .
              'WHERE account_name=? AND contract=? AND currency=? ORDER BY id');
         $sth_tokenbal_upd->execute($acc, $contract, $currency);
         my $updates = $sth_tokenbal_upd->fetchall_arrayref({});
         foreach my $row (@{$updates})
         {
             if( $row->{'deleted'} )
             {
                 $result = '0';
             }
             else
             {
                 $result = sprintf('%.'.$row->{'decimals'} . 'f', $row->{'amount'});
             }
         }

         my $res = $req->new_response(200);
         $res->content_type('text/plain');
         $res->body($result);
         $res->finalize;
     });

$builder->mount
    ('/api/topholders' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})\/([A-Z]{1,7})\/(\d+)(\/(\d+))?$/ ) {
             return(error($req, 'Expected network name, contract, token name, count, marker in URL path'));
         }

         my $network = $1;
         my $contract = $2;
         my $currency = $3;
         my $count = $4;
         my $marker = $6;

         if( $count < 10 or $count > 1000 )
         {
             return(error($req, 'Invalid count: ' . $count));
         }

         check_dbserver();

         my $sth_topholders;
         if ( $marker ) {
            $sth_topholders = $dbh->prepare
                ('SELECT account_name, CAST(amount AS DECIMAL(48,24)) AS amt, decimals ' .
                'FROM ' . $network . '_CURRENCY_BAL ' .
                'WHERE contract=? AND currency=? AND amount < ? ' .
                'ORDER BY amount DESC LIMIT ?');
            $sth_topholders->execute($contract, $currency, $marker, $count);
         } else {
            $sth_topholders = $dbh->prepare
                ('SELECT account_name, CAST(amount AS DECIMAL(48,24)) AS amt, decimals ' .
                'FROM ' . $network . '_CURRENCY_BAL ' .
                'WHERE contract=? AND currency=? ' .
                'ORDER BY amount DESC LIMIT ?');
            $sth_topholders->execute($contract, $currency, $count);
         }
         my $all = $sth_topholders->fetchall_arrayref({});
         my $result = [];
         foreach my $r (@{$all})
         {
             push(@{$result}, [$r->{'account_name'},
                               sprintf('%.'.$r->{'decimals'} . 'f', $r->{'amt'})]);
         }

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });

$builder->mount
    ('/api/holdercount' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})\/([A-Z]{1,7})$/ ) {
             return(error($req, 'Expected network name, contract, token name in URL path'));
         }

         my $network = $1;
         my $contract = $2;
         my $currency = $3;

         check_dbserver();
         my $sth_holdercount = $dbh->prepare
             ('SELECT holders ' .
              'FROM ' . $network . '_HOLDERCOUNTS ' .
              'WHERE contract=? AND currency=?');
         $sth_holdercount->execute($contract, $currency);
         my $r = $sth_holdercount->fetchall_arrayref();
         my $result = '0';
         if( scalar(@{$r}) > 0 )
         {
             $result = $r->[0];
         }

         my $res = $req->new_response(200);
         $res->content_type('text/plain');
         $res->body($result);
         $res->finalize;
     });


$builder->mount
    ('/api/key' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ ) {
             return(error($req, 'Expected an EOSIO key'))
         }

         my $result = {};
         my $accounts = {};

         my $key = from_legacy_key($1);
         check_dbserver();

         my $sth_networks = $dbh->prepare('SELECT network FROM SYNC');
         $sth_networks->execute();
         my $networs_res = $sth_networks->fetchall_arrayref();
         foreach my $netrow (@{$networs_res}) {
             my $network = $netrow->[0];

             my $sth_searchkey = $dbh->prepare
                 ('SELECT account_name, perm, pubkey, weight ' .
                  'FROM ' . $network . '_AUTH_KEYS ' .
                  'WHERE pubkey=? LIMIT 100');
             $sth_searchkey->execute($key);
             my $searchres = $sth_searchkey->fetchall_arrayref({});
             if( scalar(@{$searchres}) > 0 )
             {
                 $result->{$network}{'chain'} = get_network($network);
                 foreach my $r (@{$searchres})
                 {
                     $accounts->{$network}{$r->{'account_name'}}{$r->{'perm'}} = 1;
                 }

                 foreach my $acc (keys %{$accounts->{$network}})
                 {
                     foreach my $perm (keys %{$accounts->{$network}{$acc}})
                     {
                         get_authorized_accounts($network, $acc, $perm, $accounts);
                     }
                 }
             }

             my $sth_auth_upd = $dbh->prepare
                 ('SELECT account_name, perm, jsdata, deleted ' .
                  'FROM ' . $network . '_UPD_AUTH ORDER BY id');
             $sth_auth_upd->execute();
             my $updates = $sth_auth_upd->fetchall_arrayref({});

             foreach my $row (@{$updates})
             {
                 my $auth = $row->{'auth'} = $json->decode($row->{'jsdata'});
                 foreach my $keydata (@{$auth->{'keys'}})
                 {
                     if( $keydata->{'key'} eq $key )
                     {
                         $accounts->{$network}{$row->{'account_name'}}{$row->{'perm'}} = 1;
                         get_authorized_accounts($network, $row->{'account_name'},
                                                 $row->{'perm'}, $accounts);
                     }
                 }
             }

             foreach my $acc (keys %{$accounts->{$network}})
             {
                 $result->{$network}{'accounts'}{$acc} = get_permissions($network, $acc);
             }


             foreach my $row (@{$updates})
             {
                 my $acc = $row->{'account_name'};
                 if( defined($result->{$network}{'accounts'}{$acc}) )
                 {
                     my $perms = $result->{$network}{'accounts'}{$acc};
                     my $newperms = [];

                     foreach my $p (@{$perms})
                     {
                         if( $p->{'perm'} ne $row->{'perm'} )
                         {
                             push(@{$newperms}, $p);
                         }
                     }

                     if( not $row->{'deleted'} )
                     {
                         push(@{$newperms}, auth_upd_row_to_perm($row, $row->{'auth'}));
                     }

                     $result->{$network}{'accounts'}{$acc} = $newperms;
                 }
             }
         }

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });


$builder->mount
    ('/api/usercount' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ ) {
             return(error($req, 'Expected a network name in URL path'));
         }

         my $network = $1;
         check_dbserver();

         my $sth_usercount = $dbh->prepare
             ('SELECT count(*) as usercount FROM ' . $network . '_USERRES');
         $sth_usercount->execute();
         my $r = $sth_usercount->fetchall_arrayref();

         my $res = $req->new_response(200);
         $res->content_type('text/plain');
         $res->body($r->[0][0]);
         $res->finalize;
     });


$builder->mount
    ('/api/topram' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/(\d+)(\/(\d+))?$/ ) {
             return(error($req, 'Expected a network name, count and marker in URL path'));
         }

         my $network = $1;
         my $count = $2;
         my $marker = $4;

         if( $count < 10 or $count > 1000 )
         {
             return(error($req, 'Invalid count: ' . $count));
         }

         check_dbserver();

         my $sth_topram;
         if ( $marker ) {
            $sth_topram = $dbh->prepare
                ('SELECT account_name, ram_bytes FROM ' . $network . '_USERRES ' .
                'WHERE ram_bytes < ? ' .
                'ORDER BY ram_bytes DESC LIMIT ?');
            $sth_topram->execute($marker, $count);
         } else {
            $sth_topram = $dbh->prepare
                ('SELECT account_name, ram_bytes FROM ' . $network . '_USERRES ' .
                'ORDER BY ram_bytes DESC LIMIT ?');
            $sth_topram->execute($count);
         }

         my $all = $sth_topram->fetchall_arrayref({});
         my $result = [];
         foreach my $r (@{$all})
         {
             push(@{$result}, [$r->{'account_name'}, $r->{'ram_bytes'}]);
         }

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });


$builder->mount
    ('/api/topstake' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)\/(\d+)$/ ) {
             return(error($req, 'Expected a network name and count in URL path'));
         }

         my $network = $1;
         my $count = $2;

         if( $count < 10 or $count > 1000 )
         {
             return(error($req, 'Invalid count: ' . $count));
         }

         check_dbserver();
         my $sth_topstake = $dbh->prepare
             ('SELECT account_name, cpu_weight, net_weight FROM ' . $network . '_USERRES ' .
              'ORDER BY weight_sum DESC LIMIT ?');
         $sth_topstake->execute($count);
         my $all = $sth_topstake->fetchall_arrayref({});
         my $result = [];
         foreach my $r (@{$all})
         {
             push(@{$result}, [$r->{'account_name'}, $r->{'cpu_weight'}, $r->{'net_weight'} ]);
         }

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });



$builder->mount
    ('/api/codehash' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ or length($1) != 64 ) {
             return(error($req, 'Expected SHA256 hash'));
         }

         my $codehash = $1;
         check_dbserver();
         my $result = {};

         my $sth_networks = $dbh->prepare('SELECT network FROM SYNC');
         $sth_networks->execute();
         my $networs_res = $sth_networks->fetchall_arrayref();
         foreach my $netrow (@{$networs_res}) {
             my $network = $netrow->[0];

             my $sth_searchcode = $dbh->prepare
                 ('SELECT account_name, code_hash ' .
                  'FROM ' . $network . '_CODEHASH ' .
                  'WHERE code_hash=?');

             $sth_searchcode->execute($codehash);
             my $searchres = $sth_searchcode->fetchall_arrayref({});

             if( scalar(@{$searchres}) > 0 )
             {
                 $result->{$network}{'chain'} = get_network($network);
                 foreach my $r (@{$searchres})
                 {
                     $result->{$network}{'accounts'}{$r->{'account_name'}} = $r;
                 }
             }
         }

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });


$builder->mount
    ('/api/sync' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ ) {
             return(error($req, 'Expected a network name in URL path'));
         }

         my $network = $1;
         check_dbserver();

         $sth_sync->execute($network);
         my $r = $sth_sync->fetchall_arrayref();

         if ( scalar(@{$r}) == 0 ) {
             return(error($req, 'Unknown network name: ' . $network));
         }

         my $delay = $r->[0][0];
         my $status = ($delay <= 180) ? 'OK':'OUT_OF_SYNC';
         my $res = $req->new_response(200);
         $res->content_type('text/plain');
         $res->body(join(' ', $delay, $status));
         $res->finalize;
     });


$builder->mount
    ('/api/status' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);

         check_dbserver();
         $sth_all_sync->execute();
         my $r = $sth_all_sync->fetchall_arrayref({});

         my $status = 'OK';
         my $failed = '';
         my $http_status = 200;
         foreach my $row (@{$r}) {
             if( $row->{'sync'} > 180 ) {
                 $status = 'OUT_OF_SYNC';
                 $failed .= $row->{'network'} . ':' . $row->{'sync'} . ';';
                 $http_status = 503;
             }
         }

         my $res = $req->new_response($http_status);
         $res->content_type('text/plain');
         $res->body(join(' ', $status, $failed));
         $res->finalize;
     });




$builder->to_app;



# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 4
# cperl-continued-statement-offset: 4
# cperl-continued-brace-offset: -4
# cperl-brace-offset: 0
# cperl-label-offset: -2
# End:
