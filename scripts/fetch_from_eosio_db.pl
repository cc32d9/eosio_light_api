use strict;
use warnings;
use JSON;
use Getopt::Long;
use DBI;

$| = 1;

my $dsnr = 'DBI:MariaDB:database=eosio;host=localhost';
my $dbr_user = 'eosioro';
my $dbr_password = 'eosioro';

my $dsnw = 'DBI:MariaDB:database=tokenapi;host=localhost';
my $dbw_user = 'tokenapi';
my $dbw_password = 'ce1Shish';


my $ok = GetOptions
    ('dsnr=s'     => \$dsnr,
     'dbruser=s'  => \$dbr_user,
     'dbrpw=s'    => \$dbr_password,
     'dsnw=s'     => \$dsnw,
     'dbwuser=s'  => \$dbw_user,
     'dbwpw=s'    => \$dbw_password);


if( not $ok or scalar(@ARGV) > 0 )
{
    print STDERR "Usage: $0 [options...]\n";
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


my @prefixes;
{
    my $r = $dbhr->selectall_arrayref
        ('SELECT DISTINCT SUBSTR(account_name,1,2) FROM EOSIO_LATEST_RESOURCE');
    @prefixes = map {$_->[0]} @{$r};
}

my @res_columns = qw(account_name block_num block_time trx_id cpu_weight net_weight ram_quota ram_usage);

my $sth_getres = $dbhr->prepare
    ('SELECT ' . join(',', @res_columns) . ' ' .
     'FROM EOSIO_LATEST_RESOURCE JOIN EOSIO_ACTIONS ' .
     ' ON EOSIO_LATEST_RESOURCE.global_seq=EOSIO_ACTIONS.global_action_seq ' .
     'WHERE account_name LIKE ?');

my @bal_columns = qw(account_name block_num block_time trx_id contract currency amount);

my $sth_getbal = $dbhr->prepare
    ('SELECT ' . join(',', @bal_columns) . ' ' .
     'FROM EOSIO_LATEST_CURRENCY JOIN EOSIO_ACTIONS ' .
     ' ON EOSIO_LATEST_CURRENCY.global_seq=EOSIO_ACTIONS.global_action_seq ' .
     'WHERE account_name LIKE ?');


my $sth_checkres = $dbhw->prepare
    ('SELECT account_name, block_num ' .
     'FROM TOKENAPI_LATEST_RESOURCE WHERE account_name LIKE ?');


my $sth_inslastres = $dbhw->prepare
    ('INSERT INTO TOKENAPI_LATEST_RESOURCE ' . 
     '(account_name, block_num, block_time, trx_id, ' .
     'cpu_weight, net_weight, ram_quota, ram_usage) ' .
     'VALUES(?,?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, ' .
     'cpu_weight=?, net_weight=?, ram_quota=?, ram_usage=?');

my @instres_columns =
    qw(account_name block_num block_time trx_id cpu_weight net_weight ram_quota ram_usage
       block_num block_time trx_id cpu_weight net_weight ram_quota ram_usage);


my $sth_checkbal = $dbhw->prepare
    ('SELECT account_name, contract, currency, block_num ' .
     'FROM TOKENAPI_LATEST_CURRENCY WHERE account_name LIKE ?');

my $sth_inslastcurr = $dbhw->prepare
    ('INSERT INTO TOKENAPI_LATEST_CURRENCY ' . 
     '(account_name, block_num, block_time, trx_id, contract, currency, amount) ' .
     'VALUES(?,?,?,?,?,?,?) ' .
     'ON DUPLICATE KEY UPDATE block_num=?, block_time=?, trx_id=?, amount=?');

my @instbal_columns =
    qw(account_name block_num block_time trx_id contract currency amount
       block_num block_time trx_id amount);

my $numrows = 0;

for my $prefix (@prefixes)
{
    my $like = $prefix . '%';

    {
        $sth_checkres->execute($like);
        my $ourblocks = $sth_checkres->fetchall_hashref('account_name');
        
        $sth_getres->execute($like);
        while(my $row = $sth_getres->fetchrow_hashref('NAME_lc') )
        {
            my $acc = $row->{'account_name'};
            my $ourbl = 0;
            if( defined($ourblocks->{$acc}) )
            {
                $ourbl = $ourblocks->{$acc}{'block_num'};
            }
            
            if( $row->{'block_num'} > $ourbl )
            {
                $sth_inslastres->execute(map {$row->{$_}} @instres_columns);
                $numrows++;
            }
        }
    }

    {
        $sth_checkbal->execute($like);
        my $ourblocks = $sth_checkbal->fetchall_hashref(['account_name', 'contract', 'currency']);

        $sth_getbal->execute($like);
        while(my $row = $sth_getbal->fetchrow_hashref('NAME_lc') )
        {
            my $acc = $row->{'account_name'};
            my $contract = $row->{'contract'};
            my $currency = $row->{'currency'};
            my $ourbl = 0;
            if( defined($ourblocks->{$acc}{$contract}{$currency}) )
            {
                $ourbl = $ourblocks->{$acc}{$contract}{$currency}{'block_num'};
            }

            if( $row->{'block_num'} > $ourbl )
            {
                $sth_inslastcurr->execute(map {$row->{$_}} @instbal_columns);
                $numrows++;
            }
        }
    }

    $dbhw->commit();
    print "$numrows\n";
}


$dbhr->disconnect();
$dbhw->disconnect();

print("Finished\n");

            
                
    





     

