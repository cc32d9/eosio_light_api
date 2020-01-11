"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('wss://lightapi.eosgeneva.io/wsapi');


client.on('connected', () => { console.log('connected'); });
client.on('error', (err) => { console.error(err); });

client.methods.set("reqdata", (socket, params) => {
    console.log(JSON.stringify(params, null, 2));
    if( params.end ) {
        process.exit();
    }
});


async function send_req() {
    client.call("get_networks")
        .then(networks => {
            console.log(JSON.stringify(networks, null, 2));
            if( networks.jungle != undefined ) {
                client.call("get_token_holders", {
                    reqid: 100,
                    network: 'jungle',
                    contract: 'eosio.token',
                    currency: 'EOS'})
                    .catch(err => {
                        console.error(err);
                        process.exit();
                    });
            }
            else {
                throw Error('Cannot find jungle');
            }
        })
        .catch(err => {
            console.error(err);
            process.exit();
        });
}

send_req();


