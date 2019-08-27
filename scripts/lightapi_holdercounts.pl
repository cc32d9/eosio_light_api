use strict;
use warnings;
use Getopt::Long;
use DBI;

$| = 1;


my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


my $ok = GetOptions
    ('dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 )
{
    print STDERR "Usage: $0 [options...]\n",
    "The utility updates the counts of token holders for all tokens in all networks\n",
    "Options:\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

        

my $dbh = DBI->connect($dsn, $db_user, $db_password,
                       {'RaiseError' => 1, AutoCommit => 0,
                        mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbh;

my $sth_ins = $dbh->prepare
    ('INSERT INTO HOLDERCOUNTS(holders,network,contract,currency) VALUES(?,?,?,?)');

my $sth_upd = $dbh->prepare
    ('UPDATE HOLDERCOUNTS SET holders=? WHERE network=? AND contract=? AND currency=?');

my $sth_del = $dbh->prepare
    ('DELETE FROM HOLDERCOUNTS WHERE network=? AND contract=? AND currency=?');


my $networks = $dbh->selectall_arrayref('SELECT network from NETWORKS');

foreach my $netrow (@{$networks})
{
    my $network = $netrow->[0];

    my $chain_count_rows = $dbh->selectall_arrayref
        ('SELECT contract,currency,COUNT(*) FROM CURRENCY_BAL WHERE network=\'' . $network . '\' ' . 
         'GROUP BY contract,currency');
    my $db_count_rows = $dbh->selectall_arrayref
        ('SELECT contract,currency,holders FROM HOLDERCOUNTS WHERE network=\'' . $network . '\' ');

    my %db_counts;
    foreach my $r (@{$db_count_rows})
    {
        $db_counts{$r->[0]}{$r->[1]} = $r->[2];
    }

    my %chain_counts;
    foreach my $r (@{$chain_count_rows})
    {
        $chain_counts{$r->[0]}{$r->[1]} = $r->[2];
        
        if( defined($db_counts{$r->[0]}{$r->[1]}) )
        {
            if( $db_counts{$r->[0]}{$r->[1]} != $r->[2])
            {
                $sth_upd->execute($r->[2], $network, $r->[0], $r->[1]);
            }
        }
        else
        {
            $sth_ins->execute($r->[2], $network, $r->[0], $r->[1]);
        }
    }

    foreach my $r (@{$db_count_rows})
    {
        if( not exists($chain_counts{$r->[0]}{$r->[1]}) )
        {
            $sth_del->execute($network, $r->[0], $r->[1]);
        }
    }

    $dbh->commit();
}


$dbh->disconnect();

