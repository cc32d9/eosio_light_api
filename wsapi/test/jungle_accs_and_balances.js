"use strict";

const RPCClient = require('jsonrpc2-ws').Client;

const client = new RPCClient('ws://localhost:5010/');

var reqid = 1;
var final_reqid = 0;
var accs_buffer = new Array();
var accounts_counter = 0;


client.on('connected', () => { console.log('connected'); });
client.on('error', (err) => { console.error(err); });

client.on('error', (err) => { console.error(err); });

client.methods.set("reqdata", (socket, params) => {
    console.log(JSON.stringify(params, null, 2));
    if( params.method == 'get_accounts_from_keys' ) {
        if( params.end ) {
            final_reqid = reqid;
            return client.call("get_balances", {
                reqid: reqid,
                network: 'jungle',
                accounts: accs_buffer });
        }
        else {
            accounts_counter++;
            if( accs_buffer.length < 100 ) {
                accs_buffer.push(params.data.account_name);
                return;
            }
            else {
                let accs = Array.from(accs_buffer);
                accs_buffer = new Array();
                return client.call("get_balances", {
                    reqid: reqid++,
                    network: 'jungle',
                    accounts: accs });
            }
        }
    }
    else {
        if( params.end && params.reqid == final_reqid ) {
            console.log('TOTAL: ' + accounts_counter);
            process.exit();
        }
    }
});


async function send_req() {
    try {
        let res = await client.call("get_accounts_from_keys", {
            reqid: reqid++,
            network: 'jungle',
            keys: [
                'PUB_K1_542dRPkftgxr1jUZ6f7XaE578FR5NhEHFsxbQRS6B7nSAbrHuq',
                'PUB_K1_5uSH1kWjvs683ZzApEZks2e6Y3swwTSpkPgXbZBftxh8SWrZes',
                'PUB_K1_6JJH2tpyo7SLfTQ9Z5dU9isdxVUqJjwHhje4trT2NQxe3Kt3nZ',
                'PUB_K1_5QWKMpHuRcvMJEtpiYp5Hq53VVsgThKCPAqk9ZZPBfrrYqs9TA',
                'PUB_K1_6FgxaWwZesAzfKFTNwbXrDsvdrayHbuaC8d3cgYSgRjWA41jna',
                'PUB_K1_6FS85QseWUjiA6rohDvPEM4iwGfcLrvTPhpYNcb3yM3Mdf2fno',
                'PUB_K1_539UKNsc6hAtbZEFaEt8suVEAwHecnHNnUq1q7scSEYtpDAkL7',
            ] });
    }
    catch(err) {
        console.error(err);
    }
}

send_req();


