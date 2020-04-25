#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=proton \
     --chainid=384da888112027f0321850a169f737c33e53b388aad48b5adace4bab97f437e0 \
     --descr="Proton" --token=SYS --dec=4 ${LIGHTAPI_DB_OPTS}



