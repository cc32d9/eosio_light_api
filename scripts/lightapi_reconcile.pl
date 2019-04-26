use strict;
use warnings;
use JSON;
use LWP::UserAgent::Determined;
use HTTP::Request;
use Getopt::Long;
use DBI;

$| = 1;

my $network;
my $url = 'http://127.0.0.1:8888';

my $dsn = 'DBI:MariaDB:database=lightapi;host=localhost';
my $db_user = 'lightapi';
my $db_password = 'ce1Shish';


my %exception_contracts = ('zkstokensr4u' => 1);

my $ok = GetOptions
    ('network=s' => \$network,
     'url=s'     => \$url,
     'dsn=s'     => \$dsn,
     'dbuser=s'  => \$db_user,
     'dbpw=s'    => \$db_password);


if( not $ok or scalar(@ARGV) > 0 or not $network  )
{
    print STDERR "Usage: $0 --network=eos [options...]\n",
    "The utility compares and fixes currency balances in \n",
    "the database against blockchain\n",
    "Options:\n",
    "  --network=NAME     name of EOS network\n",
    "  --url=URL          \[$url\] EOS API URL\n",
    "  --dsn=DSN          \[$dsn\]\n",
    "  --dbuser=USER      \[$db_user\]\n",
    "  --dbpw=PASSWORD    \[$db_password\]\n";
    exit 1;
}

my $ua = LWP::UserAgent::Determined->new
    (keep_alive => 1,
     ssl_opts => { verify_hostname => 0 });
$ua->timeout(10);
$ua->env_proxy();

my $json = JSON->new->utf8(1);

my $dbh = DBI->connect($dsn, $db_user, $db_password,
                       {'RaiseError' => 1, AutoCommit => 1,
                        mariadb_server_prepare => 1});
die($DBI::errstr) unless $dbh;


my $sth_fetch = $dbh->prepare
    ('SELECT network, account_name, contract, currency, amount, deleted ' .
     'FROM LIGHTAPI_LATEST_CURRENCY WHERE network=?');

my $sth_upd_balance = $dbh->prepare
    ('UPDATE LIGHTAPI_LATEST_CURRENCY SET amount=? ' .
     'WHERE network=? AND account_name=? AND contract=? AND currency=?');

my $sth_wipe_contract = $dbh->prepare
    ('DELETE FROM LIGHTAPI_LATEST_CURRENCY WHERE network=? AND contract=?');

my $sth_del_balance = $dbh->prepare
    ('DELETE FROM LIGHTAPI_LATEST_CURRENCY ' .
     'WHERE network=? AND account_name=? AND contract=? AND currency=?');


my %invalid_contracts;

$sth_fetch->execute($network);
my $rows = $sth_fetch->fetchall_arrayref({});

while(my $r = shift(@{$rows}) )
{
    next if $r->{'deleted'};
    next if $exception_contracts{$r->{'contract'}};
    next if $invalid_contracts{$r->{'contract'}};
    
    my $req = HTTP::Request->new('POST', $url . '/v1/chain/get_currency_balance'); 
    $req->header('Content-Type' => 'application/json');
    $req->content
        ($json->encode
         ({
             'account' => $r->{'account_name'},
             'code' => $r->{'contract'},
             'symbol' => $r->{'currency'},
          }));
    
    my $response = $ua->request($req);
    if( $response->is_success() )
    {
        my $result = $json->decode($response->decoded_content());
        if( scalar(@{$result}) == 0 )
        {
            printf("Balance not found for account=%s contract=%s symbol=%s\n",
                   $r->{'account_name'}, $r->{'contract'}, $r->{'currency'});
            $sth_del_balance->execute
                ($network, $r->{'account_name'}, $r->{'contract'}, $r->{'currency'});
        }
        else
        {
            my($amount, $sym) = split(/\s+/, $result->[0]);
            if( sprintf('%f', $amount) ne sprintf('%f', $r->{'amount'}) )
            {
                printf("Wrong amount for account=%s contract=%s symbol=%s: expected %s, found %s\n",
                       $r->{'account_name'}, $r->{'contract'}, $r->{'currency'},
                       $amount, $r->{'amount'});
                $sth_upd_balance->execute
                    ($amount, $network, $r->{'account_name'}, $r->{'contract'}, $r->{'currency'});
            }
        }
    }
    else
    {
        my $regular_error = 0;
        my $remove_contract = 0;
        
        my $content = $response->decoded_content();

        if( $content =~ /^\{/ )
        {
            my $result = $json->decode($content);
            my $errname = $result->{'error'}{'name'};
            if( defined($errname) )
            {
                if( $errname eq 'contract_table_query_exception' )
                {
                    printf("Table not found for account=%s contract=%s symbol=%s\n",
                           $r->{'account_name'}, $r->{'contract'}, $r->{'currency'});
                    $regular_error = 1;
                    $remove_contract = 1;
                }
                elsif( $errname eq 'out_of_range_exception' )
                {
                    printf("Invalid table for account=%s contract=%s symbol=%s\n",
                           $r->{'account_name'}, $r->{'contract'}, $r->{'currency'});
                    $regular_error = 1;
                    $remove_contract = 1;
                }
            }
        }

        if( not $regular_error )
        {
            printf("API ERROR for account=%s contract=%s symbol=%s:\n\n%s",
                   $r->{'account_name'}, $r->{'contract'}, $r->{'currency'}, 
                   $response->decoded_content());
            exit;
        }
        elsif( $remove_contract )
        {
            $invalid_contracts{$r->{'contract'}} = 1;
            $sth_wipe_contract->execute($network, $r->{'contract'});
        }            
    }
}

$dbh->disconnect();
            
               
    
    
    
