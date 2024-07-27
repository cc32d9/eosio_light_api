#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=libre \
     --chainid=38b1d7815474d0c60683ecbea321d723e83f5da6ae5f1c1f9fecc69d9ba96465 \
     --descr="Libre" --token=LIBRE --dec=4 ${LIGHTAPI_DB_OPTS}



