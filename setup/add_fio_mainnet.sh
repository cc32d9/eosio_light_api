#!/bin/sh

perl /opt/fio_light_api/scripts/lightapi_addnet.pl \
     --network=fio \
     --chainid=21dcae42c0182200e93f954a074011f9048a7624c6fe81d3c9541a614a88bd1c \
     --descr="FIO Mainnet" --token=FIO --dec=9 ${LIGHTAPI_DB_OPTS}



