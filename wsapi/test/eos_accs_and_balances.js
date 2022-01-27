"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('wss://eos.light-api.net/wsapi');

var reqs = new Map();
var reqid = 1;
var accs_buffer = new Array();
var accounts_counter = 0;


client.on('connected', () => { console.log('connected'); });
client.on('error', (err) => { console.error(err); });

client.on('error', (err) => { console.error(err); });

client.methods.set("reqdata", (socket, params) => {
    console.log(JSON.stringify(params, null, 2));
    if( params.method == 'get_accounts_from_keys' ) {
        if( ! params.end ) {
            accounts_counter++;
            accs_buffer.push(params.data.account_name);
        }

        if( accs_buffer.length >= 100 || params.end ) {
            let accs = Array.from(accs_buffer);
            accs_buffer = new Array();
            reqs.set(reqid, 1);
            client.call("get_balances", {reqid: reqid++,
                                         network: 'eos',
                                         accounts: accs })
                .catch(err => {
                    console.error(err);
                    process.exit();
                });
        }
    }
    
    if( params.end ) {
        reqs.delete(params.reqid);
        if( reqs.size == 0 ) {
            console.log('TOTAL: ' + accounts_counter);
            process.exit();
        }
    }
});


async function send_req() {
    reqs.set(reqid, 1);
    client.call("get_accounts_from_keys", {reqid: reqid++,
                                           network: 'eos',
                                           keys: [
                                               'PUB_K1_6BXun2x4BpfecTYiLuAny5u9675Y9VVME4LSYu7g7mBmXAaGkE',
                                               'PUB_K1_7FxLHfUw7P4H59CEymvQ87jw7rMaCZTDPF28VGDVNKDV1nkHjj',
                                           ] })
        .catch(err => {
            console.error(err);
            process.exit();
        });
}

send_req();


