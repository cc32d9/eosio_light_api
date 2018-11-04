use strict;
use warnings;
use Getopt::Long;
use DBI;

$| = 1;

my $dsnr;
my $dbr_user = 'lightapiro';
my $dbr_password = 'lightapiro';

my $dsnw = 'DBI:MariaDB:database=lightapi;host=localhost';
my $dbw_user = 'lightapi';
my $dbw_password = 'ce1Shish';

my $ok = GetOptions
    ('dsnr=s'     => \$dsnr,
     'dbruser=s'  => \$dbr_user,
     'dbrpw=s'    => \$dbr_password,
     'dsnw=s'     => \$dsnw,
     'dbwuser=s'  => \$dbw_user,
     'dbwpw=s'    => \$dbw_password);


if( not $ok or scalar(@ARGV) > 0 or not $dsnr )
{
    print STDERR "Usage: $0 --dsnr='DBI:MariaDB:database=lightapi;host=HOST' [options...]\n",
    "The utility reads merges missing entries from another instance of Light API database.\n",
    "Options:\n",
    "  --dsnr=DSN          Source database DSN\n",
    "  --dbruser=USER      \[$dbr_user\]\n",
    "  --dbrpw=PASSWORD    \[$dbr_password\]\n",
    "  --dsnw=DSN          \[$dsnw\]\n",
    "  --dbwuser=USER      \[$dbw_user\]\n",
    "  --dbwpw=PASSWORD    \[$dbw_password\]\n";
    exit 1;
}


my $dbhr = DBI->connect($dsnr, $dbr_user, $dbr_password,
                        {'RaiseError' => 1, AutoCommit => 0,
                         mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbhr;

my $dbhw = DBI->connect($dsnw, $dbw_user, $dbw_password,
                        {'RaiseError' => 1, AutoCommit => 0,
                         mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbhw;


# Import only networks known in our DB
my @networks;
{
    my $r = $dbhw->selectall_arrayref('SELECT network FROM LIGHTAPI_NETWORKS');
    @networks = map {$_->[0]} @{$r};
}

my $where_network = ' WHERE network IN (' . join(',', map {'\'' . $_ . '\''} @networks) . ') ';

printf("Merging for networks: %s\n", join(', ', @networks));

printf("Processing LIGHTAPI_LATEST_RESOURCE\n");
{
    my $sthr = $dbhr->prepare
        ('SELECT * FROM LIGHTAPI_LATEST_RESOURCE' . $where_network);
    
    my $sthw_check = $dbhw->prepare
        ('SELECT block_num, irreversible FROM LIGHTAPI_LATEST_RESOURCE ' .
         'WHERE network=? AND account_name=?');
        
    my $sthw_ins = $dbhw->prepare
        ('INSERT INTO LIGHTAPI_LATEST_RESOURCE ' . 
         '(network, account_name, block_num, block_time, trx_id, ' .
         'cpu_weight, net_weight, ram_quota, ram_usage, irreversible) ' .
         'VALUES(?,?,?,?,?,?,?,?,?,1) ' .
         'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, ' .
         'cpu_weight=?, net_weight=?, ram_quota=?, ram_usage=?, irreversible=1');

    my @columns =
        qw(network account_name block_num block_time trx_id cpu_weight net_weight
           ram_quota ram_usage block_num block_time trx_id cpu_weight net_weight
           ram_quota ram_usage);

    my $c_fetched = 0;
    my $c_updated = 0;
    $sthr->execute();
    while( my $row = $sthr->fetchrow_hashref() )
    {
        $c_fetched++;
        next unless $row->{'irreversible'};

        $sthw_check->execute($row->{'network'}, $row->{'account_name'});
        my $r = $sthw_check->fetchall_arrayref();
        if( scalar(@{$r}) > 0 and $r->[0][0] >= $row->{'block_num'} and $r->[0][1] )
        {
            next;
        }

        $sthw_ins->execute(map {$row->{$_}} @columns);
        $c_updated++;
    }
        
    $dbhw->commit();
    printf("fetched %d records, updated %d\n", $c_fetched, $c_updated);
}


printf("Processing LIGHTAPI_LATEST_CURRENCY\n");
{
    my $sthr = $dbhr->prepare
        ('SELECT * FROM LIGHTAPI_LATEST_CURRENCY' . $where_network);
    
    my $sthw_check = $dbhw->prepare
        ('SELECT block_num, irreversible FROM LIGHTAPI_LATEST_CURRENCY ' .
         'WHERE network=? AND account_name=? AND contract=? AND currency=?');
        
    my $sthw_ins = $dbhw->prepare
        ('INSERT INTO LIGHTAPI_LATEST_CURRENCY ' . 
         '(network, account_name, block_num, block_time, trx_id, contract, ' .
         ' currency, amount, decimals, irreversible) ' .
         'VALUES(?,?,?,?,?,?,?,?,?,1) ' .
         'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, amount=?, irreversible=1');

    my @columns =
        qw(network account_name block_num block_time trx_id contract currency amount decimals
           block_num block_time trx_id amount);
    
    my $c_fetched = 0;
    my $c_updated = 0;
    $sthr->execute();
    while( my $row = $sthr->fetchrow_hashref() )
    {
        $c_fetched++;
        next unless $row->{'irreversible'};

        $sthw_check->execute
            ($row->{'network'}, $row->{'account_name'}, $row->{'contract'}, $row->{'currency'});
        my $r = $sthw_check->fetchall_arrayref();
        if( scalar(@{$r}) > 0 and $r->[0][0] >= $row->{'block_num'} and $r->[0][1] )
        {
            next;
        }

        $sthw_ins->execute(map {$row->{$_}} @columns);
        $c_updated++;
    }
        
    $dbhw->commit();
    printf("fetched %d records, updated %d\n", $c_fetched, $c_updated);
}


printf("Processing LIGHTAPI_AUTH_THRESHOLDS\n");
{
    my $sthr = $dbhr->prepare
        ('SELECT * FROM LIGHTAPI_AUTH_THRESHOLDS' . $where_network);
    
    my $sthw_check = $dbhw->prepare
        ('SELECT block_num, irreversible FROM LIGHTAPI_AUTH_THRESHOLDS ' .
         'WHERE network=? AND account_name=? AND perm=?');

    my $sth_ins_auth_thres = $dbhw->prepare
        ('INSERT INTO LIGHTAPI_AUTH_THRESHOLDS ' . 
         '(network, account_name, perm, threshold, block_num, block_time, trx_id, irreversible, deleted) ' .
         'VALUES(?,?,?,?,?,?,?,1,?) ' .
         'ON DUPLICATE KEY UPDATE threshold=?, block_num=?, block_time=?, trx_id=?, ' .
         'irreversible=1, deleted=?');    

    my $sth_del_auth_keys = $dbhw->prepare
        ('DELETE FROM LIGHTAPI_AUTH_KEYS WHERE network=? AND account_name=? AND perm=?');

    my $sth_del_auth_acc = $dbhw->prepare
        ('DELETE FROM LIGHTAPI_AUTH_ACC WHERE network=? AND account_name=? AND perm=?');

    my $sthr_keys = $dbhr->prepare
        ('SELECT pubkey, weight FROM LIGHTAPI_AUTH_KEYS WHERE network=? AND account_name=? AND perm=?');

    my $sthr_acc = $dbhr->prepare
        ('SELECT actor, permission, weight FROM LIGHTAPI_AUTH_ACC WHERE network=? AND account_name=? AND perm=?');

    my $sth_ins_auth_key = $dbhw->prepare
        ('INSERT INTO LIGHTAPI_AUTH_KEYS ' . 
         '(network, account_name, perm, pubkey, weight) ' .
         'VALUES(?,?,?,?,?)');

    my $sth_ins_auth_acc = $dbhw->prepare
        ('INSERT INTO LIGHTAPI_AUTH_ACC ' . 
         '(network, account_name, perm, actor, permission, weight) ' .
         'VALUES(?,?,?,?,?,?)');
    
    my $c_fetched = 0;
    my $c_updated = 0;
    $sthr->execute();
    while( my $row = $sthr->fetchrow_hashref() )
    {
        $c_fetched++;
        next unless $row->{'irreversible'};

        $sthw_check->execute
            ($row->{'network'}, $row->{'account_name'}, $row->{'perm'});
        my $r = $sthw_check->fetchall_arrayref();
        if( scalar(@{$r}) > 0 and $r->[0][0] >= $row->{'block_num'} and $r->[0][1] )
        {
            next;
        }

        $sth_ins_auth_thres->execute
            (map {$row->{$_}}
             qw(network account_name perm threshold block_num block_time trx_id deleted
                threshold block_num block_time trx_id deleted));

        my @cond = map {$row->{$_}} qw(network account_name perm);
        $sth_del_auth_keys->execute(@cond);
        $sth_del_auth_acc->execute(@cond);

        $sthr_keys->execute(@cond);
        while( my $keyrow = $sthr_keys->fetchrow_hashref() )
        {
            $sth_ins_auth_key->execute(@cond, $keyrow->{'pubkey'}, $keyrow->{'weight'});
        }

        $sthr_acc->execute(@cond);
        while( my $accrow = $sthr_acc->fetchrow_hashref() )
        {
            $sth_ins_auth_acc->execute
                (@cond, $accrow->{'actor'}, $accrow->{'permission'}, $accrow->{'weight'});
        }
             
        $c_updated++;
    }
        
    $dbhw->commit();
    printf("fetched %d records, updated %d\n", $c_fetched, $c_updated);
}




$dbhr->disconnect();
$dbhw->disconnect();
