use strict;
use warnings;
use JSON;
use DBI;
use Plack::Builder;
use Plack::Request;

# Need to make this configurable in an external file
my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapiro';
my $db_password = 'lightapiro';

my $dbh;

my $sth_allnetworks;
my $sth_getnet;
my $sth_res;
my $sth_bal;
my $sth_perms;
my $sth_keys;
my $sth_authacc;
my $sth_searchkey;
my $sth_acc_by_actor;
my $sth_sync;

sub check_dbserver
{
    if ( not defined($dbh) or not $dbh->ping() ) {
        $dbh = DBI->connect($dsn, $db_user, $db_password,
                            {'RaiseError' => 1, AutoCommit => 1,
                             'mariadb_server_prepare' => 1});
        die($DBI::errstr) unless $dbh;

        $sth_allnetworks = $dbh->prepare
            ('SELECT network, chainid, description, systoken, decimals ' .
             'FROM LIGHTAPI_NETWORKS');

        $sth_getnet = $dbh->prepare
            ('SELECT network, chainid, description, systoken, decimals ' .
             'FROM LIGHTAPI_NETWORKS WHERE network=?');

        $sth_res = $dbh->prepare
            ('SELECT block_num, block_time, trx_id, ' .
             'cpu_weight AS cpu_stake, net_weight AS net_stake, ' .
             'ram_quota AS ram_total_bytes, ram_usage AS ram_usage_bytes ' .
             'FROM LIGHTAPI_LATEST_RESOURCE ' .
             'WHERE network=? AND account_name=?');

        $sth_bal = $dbh->prepare
            ('SELECT block_num, block_time, trx_id, contract, currency, ' .
             'CAST(amount AS DECIMAL(48,24)) AS amount, decimals, deleted ' .
             'FROM LIGHTAPI_LATEST_CURRENCY ' .
             'WHERE network=? AND account_name=?');

        $sth_perms = $dbh->prepare
            ('SELECT perm, threshold, block_num, block_time, trx_id ' .
             'FROM LIGHTAPI_AUTH_THRESHOLDS ' .
             'WHERE network=? AND account_name=?');

        $sth_keys = $dbh->prepare
            ('SELECT pubkey, weight ' .
             'FROM LIGHTAPI_AUTH_KEYS ' .
             'WHERE network=? AND account_name=? AND perm=?');

        $sth_authacc = $dbh->prepare
            ('SELECT actor, permission, weight ' .
             'FROM LIGHTAPI_AUTH_ACC ' .
             'WHERE network=? AND account_name=? AND perm=?');

        $sth_searchkey = $dbh->prepare
            ('SELECT network, account_name, perm, pubkey, weight ' .
             'FROM LIGHTAPI_AUTH_KEYS ' .
             'WHERE pubkey=?');

        $sth_acc_by_actor = $dbh->prepare
            ('SELECT account_name, perm ' .
             'FROM LIGHTAPI_AUTH_ACC ' .
             'WHERE network=? AND actor=? AND permission=?');

        $sth_sync = $dbh->prepare
            ('SELECT TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) ' .
             'FROM LIGHTAPI_SYNC WHERE network=?');
    }
}


sub get_allnetworks
{
    $sth_allnetworks->execute();
    return $sth_allnetworks->fetchall_arrayref({});
}


sub get_network
{
    my $name = shift;
    $sth_getnet->execute($name);
    my $r = $sth_getnet->fetchall_arrayref({});
    return $r->[0];
}

sub get_permissions
{
    my $network = shift;
    my $acc = shift;
    
    $sth_perms->execute($network, $acc);
    my $perms = $sth_perms->fetchall_arrayref({});
    foreach my $permission (@{$perms}) {
        $sth_keys->execute($network, $acc, $permission->{'perm'});
        $permission->{'auth'}{'keys'} = $sth_keys->fetchall_arrayref({});
        
        $sth_authacc->execute($network, $acc, $permission->{'perm'});
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

    $sth_acc_by_actor->execute($network, $acc, $permission);
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
        
    

my $json = JSON->new();
my $jsonp = JSON->new()->pretty->canonical;

my $builder = Plack::Builder->new;

$builder->mount
    ('/api/networks' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);

         check_dbserver();
         my $result = get_allnetworks();

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
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected a network name and a valid EOS account name in URL path');
             return $res->finalize;
         }

         my $network = $1;
         my $acc = $2;
         check_dbserver();

         my $netinfo = get_network($network);
         if ( not defined($netinfo) ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Unknown network name: ' . $network);
             return $res->finalize;
         }

         my $result = {'account_name' => $acc, 'chain' => $netinfo};

         $sth_res->execute($network, $acc);
         $result->{'resources'} = $sth_res->fetchrow_hashref();

         $sth_bal->execute($network, $acc);
         $result->{'balances'} = $sth_bal->fetchall_arrayref({});
         foreach my $row (@{$result->{'balances'}})
         {
             $row->{'amount'} = sprintf('%.'.$row->{'decimals'} . 'f', $row->{'amount'});
         }
         
         $result->{'permissions'} = get_permissions($network, $acc);

         my $res = $req->new_response(200);
         $res->content_type('application/json');
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         $res->body($j->encode($result));
         $res->finalize;
     });

$builder->mount
    ('/api/key' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected an EOS key');
             return $res->finalize;
         }

         my $key = $1;
         check_dbserver();

         $sth_searchkey->execute($key);
         my $searchres = $sth_searchkey->fetchall_arrayref({});
         my $result = {};

         my $accounts = {};
         
         foreach my $r (@{$searchres})
         {
             my $network = $r->{'network'};
             if( not defined($result->{$network}) )
             {
                 $result->{$network}{'chain'} = get_network($network);
             }

             $accounts->{$network}{$r->{'account_name'}}{$r->{'perm'}} = 1;
         }

         foreach my $network (keys %{$accounts})
         {
             foreach my $acc (keys %{$accounts->{$network}})
             {
                 foreach my $perm (keys %{$accounts->{$network}{$acc}})
                 {
                     get_authorized_accounts($network, $acc, $perm, $accounts);
                 }
             }
         }
         
         foreach my $network (keys %{$accounts})
         {
             foreach my $acc (keys %{$accounts->{$network}})
             {
                 $result->{$network}{'accounts'}{$acc} = get_permissions($network, $acc);
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
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected a network name in URL path');
             return $res->finalize;
         }

         my $network = $1;
         check_dbserver();

         $sth_sync->execute($network);
         my $r = $sth_sync->fetchall_arrayref();

         if ( scalar(@{$r}) == 0 ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Unknown network name: ' . $network);
             return $res->finalize;
         }

         my $delay = $r->[0][0];
         my $status = ($delay <= 180) ? 'OK':'OUT_OF_SYNC';
         my $res = $req->new_response(200);
         $res->content_type('text/plain');
         $res->body(join(' ', $delay, $status));
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
