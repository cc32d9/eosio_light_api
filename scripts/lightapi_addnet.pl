use strict;
use warnings;
use Getopt::Long;
use DBI;

$| = 1;

my $network;
my $chainid;
my $description;
my $systoken;
my $decimals;
my $testnet;

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


my $ok = GetOptions
    ('network=s' => \$network,
     'chainid=s' => \$chainid,
     'descr=s'   => \$description,
     'token=s'   => \$systoken,
     'dec=i'     => \$decimals,
     'testnet'   => \$testnet,
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or not
    ($network and $chainid and $description and $systoken and $decimals) )
{
    print STDERR "Usage: $0 --network=N --chaind=ID --descr=DESCR --token=T --dec=4 [options...]\n",
    "The utility inserts an EOS network information in the database\n",
    "Options:\n",
    "  --network=NAME     name of EOS network\n",
    "  --chainid=ID       network chain ID\n",
    "  --descr=DESCR      network description\n",
    "  --token=T          system token name\n",
    "  --dec=4            system token decimals\n",
    "  --testnet          non-production network\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

        

my $dbh = DBI->connect($dsn, $db_user, $db_password,
                       {'RaiseError' => 1, AutoCommit => 0,
                        mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbh;

my $sth = $dbh->prepare
    ('INSERT INTO NETWORKS (network, chainid, description, systoken, decimals, production) ' .
     'VALUES (?,?,?,?,?,?)');
$sth->execute($network, $chainid, $description, $systoken, $decimals, ($testnet?0:1));

$sth = $dbh->prepare
    ('INSERT INTO SYNC (network, block_num, block_time, irreversible) ' .
     'VALUES (?, 0, \'2000-01-01 00:00:00\', 0)');
$sth->execute($network);
$dbh->commit();



$dbh->disconnect();
print STDERR "Added network: $network\n";

