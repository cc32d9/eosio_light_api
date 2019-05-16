#!/bin/sh

perl /opt/eosio_light_api/scripts/lightapi_addnet.pl \
     --network=eos \
     --chainid=aca376f206b8fc25a6ed44dbdc66547c36c6c33e3a119ffbeaef943642f0e906 \
     --descr="EOS Mainnet" --token=EOS --dec=4 ${LIGHTAPI_DB_OPTS}



