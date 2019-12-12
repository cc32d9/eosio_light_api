# EOSIO Light API

The API is providing information about EOSIO blockchain accounts and
token balances. It is deployed for several blockchains, such as EOS,
Telos, BOS, WAX, and Europechain. Also an endpoint for Jungle testnet is
available.

## Non-streaming requests

In below examples, "eos" stands for the name of the network where API is
taking the data.

* `http://apihost.domain/api/networks` lists all known networks and
  their information.

* Retrieve all token balances, resources and authorization information
 for an account: `http://apihost.domain/api/account/eos/ACCOUNT`

* Retrieve only token balances for an account:
  `http://apihost.domain/api/balances/eos/ACCOUNT`

* Retrieve all account information except token balances:
  `http://apihost.domain/api/accinfo/eos/ACCOUNT`

* Retrieve REX balances (fund, maturing, matured) for an account:
  `http://apihost.domain/api/rexbalance/eos/ACCOUNT`

* Retrieve raw REX information for an account (to perform calculations
  on the client side):
  `http://apihost.domain/api/rexraw/eos/ACCOUNT`

* Retrieve all accounts in all known EOSIO networks dependent on a
 public key (only up to 100 accounts are returned), including accounts
 with recursive permissions: `http://apihost.domain/api/key/KEY`

* `http://apihost.domain/api/tokenbalance/eos/ACCOUNT/CONTRACT/TOKEN`
  returns a plain text with numeric output indicating the token
  balance. Zero is returned if the token is not present or does not
  exist.

* `http://apihost.domain/api/topholders/eos/CONTRACT/TOKEN/NUM` returns
  top NUM holders of a specified token in a JSON array containing arrays
  of (account, amount) pairs. NUM must not be less than 10 or more than
  1000.

* `http://apihost.domain/api/holdercount/eos/CONTRACT/TOKEN` returns the
  total count of token holders as plain text. The result is "0" if the
  token does not exist.

* `http://apihost.domain/api/usercount/eos`
  returns a plain text with total number of accounts in the network.

* `http://apihost.domain/api/topram/eos/NUM` returns top NUM RAM buyers
  in a JSON array containing arrays of (account, bytes) pairs. NUM must
  not be less than 10 or more than 1000.

* `http://apihost.domain/api/topstake/eos/NUM` returns top NUM stake
  holders by sum of CPU and Net stakes, in a JSON array containing
  arrays of (account, cpu_weight, net_weight) tuples. NUM must not be
  less than 10 or more than 1000.

* `http://apihost.domain/api/codehash/SHA256` retrieves all accounts in
  all known EOS networks by contract hash.

* `http://apihost.domain/api/sync/eos` returns a plain text with delay
  in seconds that this server's blockchain database is behind the real
  time, and a status: OK if the delay is within 180 seconds, or
  'OUT_OF_SYNC' otherwise.

* `http://apihost.domain/api/status` returns a plain text with either
  'OK' or 'OUT_OF_SYNC' indicating the overall health of the API
  host. If any of networks experience delay higher than 3 minutes, the
  returned status is 'OUT_OF_SYNC', and HTTP status code is 503.


In addition, adding `?pretty=1` to the URL, you get the resulting JSON
sorted and formatted for human viewing.


## Streaming requests

Streaming requests utilize SSE (Server-Sent Events) to deliver bulky
data to the client. SSE is supported natively by JavaScript in modern
browsers and in `nodejs`.

At the end of each API request, the server sends an `end` event. The
data is a JSON object with `count` and `reason` fields. The reason can
be `ok` for normal finishing, or `timeout` if the request lasts for
more than 60 seconds. Normally the client should close the SSE socket
upon receiving the `end` event type.

* `http://apihost.domain/api/sse/balances_by_key?network=NETWORK&key=KEY`
  searches non-recursively for accounts matching a specified public
  key as `active` or `owner` permission, and retrieves token balances
  for each account. The request returns an `account_balances` event
  for each matched account, and the data field contains a JSON object
  with the fields `account` and `balances`.


User discussion and support in Telegram: https://t.me/lightapi


## Public endpoints

A list of public API endpoints is served by IPFS, and available with the
following links:

* https://endpoints.light.xeos.me/endpoints.json  (served by Cloudflare)

* https://ipfs.io/ipns/QmTuBHRokSuiLBiqE1HySfK1BFiT2pmuDTuJKXNganE52N/endpoints.json


## Project sponsors

* [GetScatter](https://get-scatter.com/): engineering, hosting and
  maintenance.

* [EOS Cafe Block](https://www.eoscafeblock.com/): new features.

* [Telos community](https://telosfoundation.io/): development of
  additional features in Chronicle.

* [EOS Amsterdam](https://eosamsterdam.net/) and
  [Newdex](https://newdex.io/): development of Version 2.

* [EOS Amsterdam](https://eosamsterdam.net/): hosting for BOS, WAX,
  Europechain, Worbli and Instar blockchains.

* [Worbli](https://worbli.io/) and [EOS
  Amsterdam](https://eosamsterdam.net/): hosting and maintenance of
  service in Singapore.
  
* [SOV](https://www.soveos.one/): new features.

## Installation

```
sudo apt-get install git make cpanminus gcc g++ mariadb-server \
libmysqlclient-dev libdbi-perl libjson-xs-perl libjson-perl libdatetime-format-iso8601-perl

sudo cpanm DBD::MariaDB
sudo cpanm Starman
sudo cpanm Net::WebSocket::Server
sudo cpanm Crypt::Digest::RIPEMD160;


git clone -b v2 https://github.com/cc32d9/eosio_light_api.git /opt/eosio_light_api
cd /opt/eosio_light_api

sudo mysql <sql/lightapi_dbcreate.sql
sh setup/add_eos_mainnet.sh

vi /etc/default/lightapi_eos
# add the Chronicle consumer socket details:
# DBWRITE_OPTS=--port=8100

# Optionally, edit /etc/default/lightapi_api and adjust variables
# that are predefined in systemd/lightapi_api.service

cd systemd
sh install_systemd_dbwrite.sh eos
sh install_systemd_api.sh

# Now Starman is serving HTTP requests and you can build your HTTP service
# with nginx or exposing Starman directly


# Cron job for token holder counts
cat >/etc/cron.d/lightapi <<'EOT'
*/5 * * * * root perl /opt/eosio_light_api/scripts/lightapi_holdercounts.pl
EOT
```




## Copyright and License

Copyright 2018-2019 cc32d9@gmail.com

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
