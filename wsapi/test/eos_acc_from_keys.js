"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('wss://eos.light-api.net/wsapi');


client.on('connected', () => { console.log('connected'); });
client.on('error', (err) => { console.error(err); });

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
            if( networks.eos != undefined ) {
                client.call("get_accounts_from_keys", {
                    reqid: 100,
                    network: 'eos',
                    keys: ['PUB_K1_5VixV8YBKz6vkFCXzLauNmLfyHEVx6ipzYHoKbDL1uojZnYFPz',
                           'PUB_K1_6kjcm42sprt55d9zoPgJagZEyxpwAztHNexjBvSkJsQoQVB8MH'] })
                    .then(res => {
                        console.log(JSON.stringify(res, null, 2));
                    });
            }
            else {
                throw Error('Cannot find eos');
            }
        })
        .catch(err => {
            console.error(err);
            process.exit();
        });
}


send_req();


