"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('wss://lightapi.eosgeneva.io/wsapi');

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
                                         network: 'jungle',
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
                                           network: 'jungle',
                                           keys: [
                                               'PUB_K1_542dRPkftgxr1jUZ6f7XaE578FR5NhEHFsxbQRS6B7nSAbrHuq',
                                               'PUB_K1_5uSH1kWjvs683ZzApEZks2e6Y3swwTSpkPgXbZBftxh8SWrZes',
                                               'PUB_K1_6JJH2tpyo7SLfTQ9Z5dU9isdxVUqJjwHhje4trT2NQxe3Kt3nZ',
                                               'PUB_K1_5QWKMpHuRcvMJEtpiYp5Hq53VVsgThKCPAqk9ZZPBfrrYqs9TA',
                                               'PUB_K1_6FgxaWwZesAzfKFTNwbXrDsvdrayHbuaC8d3cgYSgRjWA41jna',
                                               'PUB_K1_6FS85QseWUjiA6rohDvPEM4iwGfcLrvTPhpYNcb3yM3Mdf2fno',
                                               'PUB_K1_539UKNsc6hAtbZEFaEt8suVEAwHecnHNnUq1q7scSEYtpDAkL7',
                                           ] })
        .catch(err => {
            console.error(err);
            process.exit();
        });
}

send_req();


