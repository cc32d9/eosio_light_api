use strict;
use warnings;
use JSON;
use Getopt::Long;
use DBI;
use Math::BigFloat;
use DateTime;
use DateTime::Format::ISO8601;

$| = 1;

my $network;

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';

my $ok = GetOptions
    ('network=s' => \$network,
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or not $network )
{
    print STDERR "Usage: $0 --network=eos [options...]\n",
    "The utility reports all system token balances, including stake and REX\n",
    "Options:\n",
    "  --network=NAME     name of EOS network\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

my $dbh = DBI->connect($dsn, $db_user, $db_password,
                       {'RaiseError' => 1, AutoCommit => 0,
                        mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbh;


my $res = $dbh->selectall_arrayref
    ('SELECT systoken, decimals FROM NETWORKS WHERE network=\'' . $network . '\'');

die('no such network') unless scalar(@{$res});

my $systoken = $res->[0][0];
my $decimals = $res->[0][1];

my %bal;

my $sth = $dbh->prepare
    ('SELECT account_name, amount FROM CURRENCY_BAL WHERE network=? AND contract=\'eosio.token\' AND currency=?');

$sth->execute($network, $systoken);
while( my $r = $sth->fetchrow_arrayref() )
{
    $bal{$r->[0]} = $r->[1];
}


$sth = $dbh->prepare
    ('SELECT del_from, cpu_weight+net_weight FROM DELBAND WHERE network=?');

$sth->execute($network);
while( my $r = $sth->fetchrow_arrayref() )
{
    my $acc = $r->[0];
    my $stake = $r->[1] / (10**$decimals);
    if( exists($bal{$acc}) )
    {
        $bal{$acc} += $stake;
    }
    else
    {
        $bal{$acc} = $stake;
    }
}



$res = $dbh->selectall_arrayref
    ('SELECT total_lendable/(total_rex*10000) FROM REXPOOL WHERE network=\'' . $network . '\'');

if( scalar(@{$res}) )
{
    my $rexprice = Math::BigFloat->new($res->[0][0]);
    my $now = DateTime->now('time_zone' => 'UTC');
    my $end_of_time = DateTime->from_epoch('epoch' => 0xffffffff, 'time_zone' => 'UTC');

    $sth = $dbh->prepare
        ('SELECT ' .
         'account_name, balance ' .
         'FROM REXFUND ' .
         'WHERE network=?');

    $sth->execute($network);
    while( my $r = $sth->fetchrow_arrayref() )
    {
        my $acc = $r->[0];
        my $fund = $r->[1];

        if( exists($bal{$acc}) )
        {
            $bal{$acc} += $fund;
        }
        else
        {
            $bal{$acc} = $fund;
        }
    }

    
    $sth = $dbh->prepare
        ('SELECT ' .
         'account_name, matured_rex, rex_maturities ' .
         'FROM REXBAL ' .
         'WHERE network=?');

    $sth->execute($network);
    while( my $r = $sth->fetchrow_arrayref() )
    {
        my $acc = $r->[0];
        my $maturing_rex = Math::BigFloat->new(0);
        my $matured_rex = Math::BigFloat->new($r->[1]);
        my $savings_rex = Math::BigFloat->new(0);

        my $maturities = decode_json($r->[2]);

        foreach my $enry (@{$maturities})
        {
            my $mt = DateTime::Format::ISO8601->parse_datetime($enry->{'first'});
            $mt->set_time_zone('UTC');

            if( DateTime->compare($mt, $now) <= 0 ) {
                $matured_rex += $enry->{'second'};
            }
            else {
                if( DateTime->compare($mt, $end_of_time) == 0 ) {
                    $savings_rex += $enry->{'second'};
                }
                else {
                    $maturing_rex += $enry->{'second'};
                }
            }
        }

        my $rexbal = $maturing_rex->badd($matured_rex)->badd($savings_rex)->bmul($rexprice);
        
        if( exists($bal{$acc}) )
        {
            $bal{$acc} += $rexbal;
        }
        else
        {
            $bal{$acc} = $rexbal;
        }
    }
}

$dbh->disconnect();

foreach my $acc (sort keys %bal)
{
    printf('%s,%.'.$decimals . "f\n", $acc, $bal{$acc});
}



        
        




     
