#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=bos \
     --chainid=d5a3d18fbb3c084e3b1f3fa98c21014b5f3db536cc15d08f9f6479517c6a3d86 \
     --descr="BOS Mainnet" --token=BOS --dec=4 ${LIGHTAPI_DB_OPTS}



