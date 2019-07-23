#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=xec \
     --chainid=f778f7d2f124b110e0a71245b310c1d0ac1a0edd21f131c5ecb2e2bc03e8fe2e \
     --descr="Europechain" --token=XEC --dec=4 ${LIGHTAPI_DB_OPTS}



