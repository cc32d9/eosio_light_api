use strict;
use warnings;
use JSON;
use DBI;
use Math::BigInt;
use Crypt::Digest::RIPEMD160 qw(ripemd160 ripemd160_hex);
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
my $sth_tokenbal;
my $sth_topholders;
my $sth_perms;
my $sth_keys;
my $sth_authacc;
my $sth_linkauth;
my $sth_delegated_from;
my $sth_delegated_to;
my $sth_get_code;
my $sth_searchkey;
my $sth_acc_by_actor;
my $sth_usercount;
my $sth_topram;
my $sth_searchcode;
my $sth_sync;

sub check_dbserver
{
    if ( not defined($dbh) or not $dbh->ping() ) {
        $dbh = DBI->connect($dsn, $db_user, $db_password,
                            {'RaiseError' => 1, AutoCommit => 1,
                             'mariadb_server_prepare' => 1});
        die($DBI::errstr) unless $dbh;

        $sth_allnetworks = $dbh->prepare
            ('SELECT network, chainid, description, systoken, decimals, production ' .
             'FROM NETWORKS');

        $sth_getnet = $dbh->prepare
            ('SELECT network, chainid, description, systoken, decimals, production ' .
             'FROM NETWORKS WHERE network=?');

        $sth_res = $dbh->prepare
            ('SELECT block_num, block_time, ' .
             'cpu_weight, net_weight, ' .
             'ram_bytes ' .
             'FROM USERRES ' .
             'WHERE network=? AND account_name=?');

        $sth_bal = $dbh->prepare
            ('SELECT block_num, block_time, contract, currency, ' .
             'CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' .
             'FROM CURRENCY_BAL ' .
             'WHERE network=? AND account_name=?');

        $sth_tokenbal = $dbh->prepare
            ('SELECT CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' .
             'FROM CURRENCY_BAL ' .
             'WHERE network=? AND account_name=? AND contract=? AND currency=?');

        $sth_topholders = $dbh->prepare
            ('SELECT account_name, CAST(amount AS DECIMAL(48,24)) AS amt, decimals ' .
             'FROM CURRENCY_BAL ' .
             'WHERE network=? AND contract=? AND currency=? ' .
             'ORDER BY amount DESC LIMIT ?');
        
        $sth_perms = $dbh->prepare
            ('SELECT perm, threshold, block_num, block_time ' .
             'FROM AUTH_THRESHOLDS ' .
             'WHERE network=? AND account_name=?');

        $sth_keys = $dbh->prepare
            ('SELECT pubkey, weight ' .
             'FROM AUTH_KEYS ' .
             'WHERE network=? AND account_name=? AND perm=?');

        $sth_authacc = $dbh->prepare
            ('SELECT actor, permission, weight ' .
             'FROM AUTH_ACC ' .
             'WHERE network=? AND account_name=? AND perm=?');

        $sth_linkauth = $dbh->prepare
            ('SELECT code, type, requirement, block_num, block_time ' .
             'FROM LINKAUTH ' .
             'WHERE network=? AND account_name=?');

        $sth_delegated_from = $dbh->prepare
            ('SELECT del_from, cpu_weight, net_weight, block_num, block_time ' .
             'FROM DELBAND ' .
             'WHERE network=? AND account_name=?');
        
        $sth_delegated_to = $dbh->prepare
            ('SELECT account_name, cpu_weight, net_weight, block_num, block_time ' .
             'FROM DELBAND ' .
             'WHERE network=? AND del_from=?');

        $sth_get_code = $dbh->prepare
            ('SELECT code_hash, block_num, block_time ' .
             'FROM CODEHASH ' .
             'WHERE network=? AND account_name=?');
        
        $sth_searchkey = $dbh->prepare
            ('SELECT network, account_name, perm, pubkey, weight ' .
             'FROM AUTH_KEYS ' .
             'WHERE pubkey=?');

        $sth_acc_by_actor = $dbh->prepare
            ('SELECT account_name, perm ' .
             'FROM AUTH_ACC ' .
             'WHERE network=? AND actor=? AND permission=?');

        $sth_usercount = $dbh->prepare
            ('SELECT count(*) as usercount FROM USERRES WHERE network=?');
        
        $sth_topram = $dbh->prepare
            ('SELECT account_name, ram_bytes FROM USERRES ' .
             'WHERE network=? ORDER BY ram_bytes DESC LIMIT ?');

        $sth_searchcode = $dbh->prepare
            ('SELECT network, account_name, code_hash, block_num, block_time ' .
             'FROM CODEHASH ' .
             'WHERE code_hash=?');
        
        $sth_sync = $dbh->prepare
            ('SELECT TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) ' .
             'FROM SYNC WHERE network=?');
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
    
    $sth_perms->execute($network, $acc);
    my $perms = $sth_perms->fetchall_arrayref({});
    foreach my $permission (@{$perms}) {
        $sth_keys->execute($network, $acc, $permission->{'perm'});
        $permission->{'auth'}{'keys'} = $sth_keys->fetchall_arrayref({});
        foreach my $row (@{$permission->{'auth'}{'keys'}})
        {
            my $newformat = $row->{'pubkey'};
            $row->{'pubkey'} = to_legacy_key($newformat);
            $row->{'public_key'} = $newformat;
        }
        
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

         $sth_linkauth->execute($network, $acc);
         $result->{'linkauth'} = $sth_linkauth->fetchall_arrayref({});

         $sth_delegated_from->execute($network, $acc);
         $result->{'delegated_from'} = $sth_delegated_from->fetchall_arrayref({});
         
         $sth_delegated_to->execute($network, $acc);
         $result->{'delegated_to'} = $sth_delegated_to->fetchall_arrayref({});


         $sth_get_code->execute($network, $acc);
         my $r = $sth_get_code->fetchall_arrayref({});
         if( scalar(@{$r}) > 0 )
         {
             $result->{'code'} = $r->[0];
         }
             
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
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected network name, account, contract, and token name in URL path');
             return $res->finalize;
         }

         my $network = $1;
         my $acc = $2;
         my $contract = $3;
         my $currency = $4;
         check_dbserver();
         $sth_tokenbal->execute($network, $acc, $contract, $currency);
         my $r = $sth_tokenbal->fetchall_arrayref({});
         my $result = '0';
         if( scalar(@{$r}) > 0 )
         {
             $result = sprintf('%.'.$r->[0]{'decimals'} . 'f', $r->[0]{'amount'});
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

         if ( $path_info !~ /^\/(\w+)\/([a-z1-5.]{1,13})\/([A-Z]{1,7})\/(\d+)$/ ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected network name, contract, token name, count in URL path');
             return $res->finalize;
         }

         my $network = $1;
         my $contract = $2;
         my $currency = $3;
         my $count = $4;

         if( $count < 10 or $count > 1000 )
         {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Invalid count: ' . $count);
             return $res->finalize;
         }
             
         check_dbserver();
         $sth_topholders->execute($network, $contract, $currency, $count);
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

         my $key = from_legacy_key($1);
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
    ('/api/usercount' => sub {
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

         $sth_usercount->execute($network);
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

         if ( $path_info !~ /^\/(\w+)\/(\d+)$/ ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected a network name and count in URL path');
             return $res->finalize;
         }

         my $network = $1;
         my $count = $2;

         if( $count < 10 or $count > 1000 )
         {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Invalid count: ' . $count);
             return $res->finalize;
         }
             
         check_dbserver();
         $sth_topram->execute($network, $count);
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
    ('/api/codehash' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;

         if ( $path_info !~ /^\/(\w+)$/ or length($1) != 64 ) {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected SHA256 hash');
             return $res->finalize;
         }

         my $codehash = $1;
         check_dbserver();

         $sth_searchcode->execute($codehash);
         my $searchres = $sth_searchcode->fetchall_arrayref({});
         my $result = {};
         
         foreach my $r (@{$searchres})
         {
             my $network = $r->{'network'};
             if( not defined($result->{$network}) )
             {
                 $result->{$network}{'chain'} = get_network($network);
             }

             $result->{$network}{'accounts'}{$r->{'account_name'}} = $r;
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
