#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=wax \
     --chainid=1064487b3cd1a897ce03ae5b6a865651747e2e152090f99c1d19d44e01aea5a4 \
     --descr="WAX" --token=WAX --dec=8 ${LIGHTAPI_DB_OPTS}



