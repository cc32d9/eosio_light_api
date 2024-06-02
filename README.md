# EOSIO Light API

The API is providing information about EOSIO blockchain accounts and
token balances. It is deployed for several blockchains, such as EOS,
Telos, BOS, WAX, and Europechain. Also an endpoints for a number of
testnets are available.

## HTTP API

In below examples, "CHAIN" stands for the name of the network where API is
taking the data (such as `eos`, `telos`, `wax` etc.).

* `http://apihost.domain/api/networks` lists all known networks and
  their information.

* Retrieve all token balances, resources and authorization information
 for an account: `http://apihost.domain/api/account/CHAIN/ACCOUNT`

* Retrieve only token balances for an account:
  `http://apihost.domain/api/balances/CHAIN/ACCOUNT`

* Retrieve all account information except token balances:
  `http://apihost.domain/api/accinfo/CHAIN/ACCOUNT`

* Retrieve REX balances (fund, maturing, matured) for an account:
  `http://apihost.domain/api/rexbalance/CHAIN/ACCOUNT`

* Retrieve raw REX information for an account (to perform calculations
  on the client side):
  `http://apihost.domain/api/rexraw/CHAIN/ACCOUNT`

* Retrieve all accounts in all known EOSIO networks dependent on a
 public key (only up to 100 accounts are returned), including accounts
 with recursive permissions: `http://apihost.domain/api/key/KEY`

* `http://apihost.domain/api/tokenbalance/CHAIN/ACCOUNT/CONTRACT/TOKEN`
  returns a plain text with numeric output indicating the token
  balance. Zero is returned if the token is not present or does not
  exist.

* `http://apihost.domain/api/topholders/CHAIN/CONTRACT/TOKEN/NUM[/MARKER]` returns
  top NUM holders of a specified token in a JSON array containing arrays
  of (account, amount) pairs. NUM must not be less than 10 or more than
  1000. MARKER is token integer as pagination offset.

* `http://apihost.domain/api/holdercount/CHAIN/CONTRACT/TOKEN` returns the
  total count of token holders as plain text. The result is "0" if the
  token does not exist.

* `http://apihost.domain/api/usercount/CHAIN`
  returns a plain text with total number of accounts in the network.

* `http://apihost.domain/api/topram/CHAIN/NUM[/MARKER]` returns top NUM RAM buyers
  in a JSON array containing arrays of (account, bytes) pairs. NUM must
  not be less than 10 or more than 1000. MARKER is bytes number as pagination
  offset.

* `http://apihost.domain/api/topstake/CHAIN/NUM` returns top NUM stake
  holders by sum of CPU and Net stakes, in a JSON array containing
  arrays of (account, cpu_weight, net_weight) tuples. NUM must not be
  less than 10 or more than 1000.

* `http://apihost.domain/api/codehash/SHA256` retrieves all accounts in
  all known networks by contract hash.

* `http://apihost.domain/api/sync/CHAIN` returns a plain text with delay
  in seconds that this server's blockchain database is behind the real
  time, and a status: OK if the delay is within 180 seconds, or
  'OUT_OF_SYNC' otherwise.

* `http://apihost.domain/api/status` returns a plain text with either
  'OK' or 'OUT_OF_SYNC' indicating the overall health of the API
  host. If any of networks experience delay higher than 3 minutes, the
  returned status is 'OUT_OF_SYNC', and HTTP status code is 503.


In addition, adding `?pretty=1` to the URL, you get the resulting JSON
sorted and formatted for human viewing.

## Websocket API

Websocket API is complimentary to HTTP API and is designed for bulk
requests. All communication is compliant with [JSON-RPC version
2.0](https://www.jsonrpc.org/specification).

The client is expected to close the websoclet connection after it
finishes using it. The server sends periodic websocket ping requests
and terminates the connection if the client fails to respond.

Bulk methods `get_accounts_from_keys` and `get_balances` require a
parameter `reqid`. The requests return immediately, and the API starts
sending RPC notifications. Each notification has the following fields:

* `method`: the original RPC method that caused the notification;

* `reqid`: the same value as was passed in `reqid` when calling the
  request;

* `data`: row of data according to request. It is omitted when `end`
  is `true`;

* `end`: if present and is `true`, this is the last notification for
  this `reqid`. Additional fields `status` and `error` are delivered
  to indicate the success of operation.

* `status`: only present in the end notification. Value 200 indicates
  success, and 500 indicates an error.

* `error`: only present in the end notification. In case of success,
  this field is set to `null`, and contains an error message
  otherwise.

Notifications are sent asynchronously, and if multiple requests are
being served, the order of interleaving is random. But within each
`reqid` the order of messages is guaranteed to have `end` message as
the last one.

Methods that return token balances deliver the amounts as strings with
exact number of decimals as specified in the token contract.


RPC methods:

* `get_networks` does not require any parameters, and returns a map of
  network name as key and a map of `network, chainid, description,
  systoken, decimals, production` as value.

* `get_accounts_from_keys` requires the following parameters: `reqid`,
  `network`, `keys` (array of public keys to search for, up to 100
  keys). The method generates notifications with `account_name, perm,
  weight, pubkey` in data field. Both legacy and new format of keys
  are supported.

* `get_balances` requires the following parameters: `reqid`,
  `network`, `accounts` (array of account names, up to 100
  accounts). The method generates notifications with `account,
  balances` in the data field, where balances are in an array of maps
  with `contract, currency, amount` keys.

* `get_token_holders` requires the following parameters: `reqid`,
  `network`, `contract` and `currency`. The method generates
  notifications with `account, amount` in the data field, returning
  all token holders and their balances.


## User support

User discussion and support in Telegram: https://t.me/lightapi


## Public endpoints

[A list of public API endpoints](endpoints.json) is served by IPFS,
and available with the following link:

* https://endpoints.light-api.net/endpoints.json  (served by Cloudflare)



## Project sponsors

* [GetScatter](https://get-scatter.com/): engineering, hosting and
  maintenance.

* [EOS Cafe Block](https://www.eoscafeblock.com/): new features.

* [Telos community](https://telosfoundation.io/): development of
  additional features in Chronicle.

* [EOS Amsterdam](https://eosamsterdam.net/) and
  [Newdex](https://newdex.io/): development of Version 2

* [EOS Amsterdam](https://eosamsterdam.net/): hosting for most public
  blockchains.
  
* [SOV](https://www.soveos.one/): new features.



## Installation

The database writer process (`lightapi_dbwrite.pl`) is a consumer for
[Chronicle](https://github.com/EOSChronicleProject) data feed, and it
writes the blockchain information in real time into the local MariaDB
database.

```
apt-get install git make cpanminus gcc g++ mariadb-server \
libmysqlclient-dev libdbi-perl libjson-xs-perl libjson-perl libdatetime-format-iso8601-perl

cpanm --notest DBD::MariaDB
cpanm --notest Starman
cpanm --notest Net::WebSocket::Server
cpanm --notest Crypt::Digest::RIPEMD160;


git clone https://github.com/cc32d9/eosio_light_api.git /opt/eosio_light_api

cd /opt/eosio_light_api/sql
mysql <lightapi_dbcreate.sql
sh create_tables.sh eos
sh /opt/eosio_light_api/setup/add_eos_mainnet.sh

curl -sL https://deb.nodesource.com/setup_13.x | bash -
apt install -y nodejs
cd /opt/eosio_light_api/wsapi
npm install

vi /etc/default/lightapi_eos
# add the Chronicle consumer socket details:
# DBWRITE_OPTS=--port=8100

# Optionally, edit /etc/default/lightapi_api and adjust variables
# that are predefined in systemd/lightapi_api.service

cd /opt/eosio_light_api/systemd
sh install_systemd_dbwrite.sh eos
sh install_systemd_api.sh
sh install_systemd_wsapi.sh 5101 5102 5103 5104 5105

# Now Starman is serving HTTP requests and you can build your HTTP service
# with nginx or exposing Starman directly


# Cron job for token holder counts
cat >/etc/cron.d/lightapi <<'EOT'
*/5 * * * * root perl /opt/eosio_light_api/scripts/lightapi_holdercounts.pl
EOT

## set up chronicle

cd /var/local
wget https://github.com/EOSChronicleProject/eos-chronicle/releases/download/v2.2/eosio-chronicle-2.2-Clang-11.0.1-ubuntu20.04-x86_64.deb
apt install ./eosio-chronicle-2.2-Clang-11.0.1-ubuntu20.04-x86_64.deb
cp /usr/local/share/chronicle_receiver\@.service /etc/systemd/system/
systemctl daemon-reload


# Chronicle configuration:
# host, port point to the EOSIO/Leap state history source
# exp-ws-host, exp-ws-port point to the lightapi_dbwrite.pl process
# blacklist reduces the amount of processing on bulky contracts
mkdir -p /srv/eos/chronicle-config
cat >/srv/eos/chronicle-config/config.ini <<'EOT'
host = 10.0.3.1
port = 9090
mode = scan
plugin = exp_ws_plugin
exp-ws-host = 127.0.0.1
exp-ws-port = 8100
exp-ws-bin-header = true
skip-block-events = true
skip-traces = true
blacklist-tables-contract = atomicassets
blacklist-tables-contract = atomicmarket
EOT

# You need to initialize the Chronicle database from the first block
# in the state history archive. See the Chronicle Tutorial for more
# details. You may point it to some other state history source during
# the initialization. Here we launch it in scan-noexport mode for faster initialization.
/usr/local/sbin/chronicle-receiver --config-dir=/srv/eos/chronicle-config \
 --data-dir=/srv/eos/chronicle-data \
 --host=my.ship.host.domain.com --port=8080 \
 --start-block=186332760 

# Once it displays the progress of acknowledged blocks, stop it and start as a service
systemctl enable chronicle_receiver@memento_wax1
systemctl start chronicle_receiver@memento_wax1


```


## Public database access

A replica of LightAPI databases is provided by EOS Amsterdam for
public access. The goal is to allow queries which are not implemented
by the API. There is no SLA, and the service is offered at best
effort. You can query the SYNC table to see if the data is up to date.

Access to the database is throttled on the network level for the sake
of fair use.

The database schema is available in
[sql/lightapi_dbcreate.sql](sql/lightapi_dbcreate.sql).

```
mysql --host=pubdb.eu.eosamsterdam.net --port=3301 --user=lightapiro \
  --password=lightapiro --database=lightapi
```

Query examples:

```
select * from wax_CURRENCY_BAL where account_name = 'cc32dninexxx';

select * from wax_CURRENCY_BAL where contract='eosio.token' and currency='WAX' and amount > 500000;

select count(*) from wax_USERRES where account_name like '%.wam';
```


## Copyright and License

Copyright 2018-2021 cc32d9@gmail.com

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


## Donations and paid service

ETH address: `0x7137bfe007B15F05d3BF7819d28419EAFCD6501E`

EOS account: `cc32dninexxx`
