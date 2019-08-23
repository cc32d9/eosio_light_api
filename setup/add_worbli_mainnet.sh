#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=worbli \
     --chainid=73647cde120091e0a4b85bced2f3cfdb3041e266cbbe95cee59b73235a1b3b6f\
     --descr="Worbli" --token=WBI --dec=4 ${LIGHTAPI_DB_OPTS}



