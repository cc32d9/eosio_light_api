#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=telos \
     --chainid=4667b205c6838ef70ff7988f6e8257e8be0e1284a2f59699054a018f743b1d11 \
     --descr="Telos Mainnet" --token=TLOS --dec=4 ${LIGHTAPI_DB_OPTS}



