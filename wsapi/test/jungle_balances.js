"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('ws://localhost:5010/');


client.on('connected', () => { console.log('connected'); });
client.on('error', (err) => { console.error(err); });

async function send_req() {
    try {
        let res = await client.call("get_balances", {
            network: 'jungle',
            accounts: ['cc32dninexxx', 'training1111'] });
        console.log(JSON.stringify(res, null, 2));
    }
    catch(err) {
        console.error(err);
    }

    process.exit();
}

send_req();


