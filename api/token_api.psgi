use strict;
use warnings;
use JSON;
use DBI;
use Plack::Builder;
use Plack::Request;

# Need to make this configurable in an external file
my $dsn = 'DBI:mysql:database=tokenapi;host=localhost';
my $db_user = 'tokenapiro';
my $db_password = 'tokenapiro';

my $dbh;
my $sth_res;
my $sth_bal;

sub check_dbserver
{
    if( not defined($dbh) or not $dbh->ping() )
    {
        $dbh = DBI->connect($dsn, $db_user, $db_password,
                            {'RaiseError' => 1, AutoCommit => 0,
                             'mysql_auto_reconnect' => 1});
        die($DBI::errstr) unless $dbh;

        $sth_res = $dbh->prepare
            ('SELECT block_num, block_time, trx_id, ' .
             'cpu_weight AS cpu_stake, net_weight AS net_stake, ' .
             'ram_quota AS ram_total_bytes, ram_usage AS ram_usage_bytes ' .
             'FROM TOKENAPI_LATEST_RESOURCE ' .
             'WHERE account_name=?');
        
        $sth_bal = $dbh->prepare
            ('SELECT block_num, block_time, trx_id, issuer AS contract, currency, amount ' .
             'FROM TOKENAPI_LATEST_CURRENCY ' .
             'WHERE account_name=?');
    }
}


    
my $json = JSON->new();
my $jsonp = JSON->new()->pretty->canonical;

my $builder = Plack::Builder->new;

$builder->mount
    ('/api/account' => sub {
         my $env = shift;
         my $req = Plack::Request->new($env);
         my $path_info = $req->path_info;
         
         if( $path_info !~ /^\/([a-z1-5.]{1,13})$/ )
         {
             my $res = $req->new_response(400);
             $res->content_type('text/plain');
             $res->body('Expected a valid EOS account name in URL path');
             return $res->finalize;
         }

         my $acc = $1;         
         my $j = $req->query_parameters->{pretty} ? $jsonp:$json;
         
         my $result = {'account_name' => $acc};

         check_dbserver();

         $sth_res->execute($acc);
         $result->{'resources'} = $sth_res->fetchrow_hashref();

         $sth_bal->execute($acc);
         $result->{'balances'} = $sth_bal->fetchall_arrayref({});

         $dbh->commit();
         
         my $res = $req->new_response(200);
         $res->content_type('application/json');

         $res->body($j->encode($result));
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
