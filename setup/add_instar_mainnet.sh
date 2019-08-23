#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=instar \
     --chainid=b042025541e25a472bffde2d62edd457b7e70cee943412b1ea0f044f88591664 \
     --descr="INSTAR" --token=INSTAR --dec=4 ${LIGHTAPI_DB_OPTS}



