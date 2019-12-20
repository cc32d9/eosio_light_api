"use strict";

const mariadb   = require('mariadb');
var nconf = require('nconf');
const RPCServer = require('jsonrpc2-ws').Server;
const Numeric = require('eosjs/dist/eosjs-numeric');


nconf.defaults({
    'dbhost':     'localhost',
    'dnmame':     'lightapi',
    'dbuser':     'lightapiro',
    'dbpassword': 'lightapiro',
    'dbmaxconn':  20,
    'httpport':   5010,
    'httphost':   '127.0.0.1',
    'get_balances_max':           100,
    'get_accounts_from_keys_max': 100
});

nconf.env().argv();

const pool = mariadb.createPool({
    host:       nconf.get('dbhost'),
    user:       nconf.get('dbuser'),
    password:   nconf.get('dbpassword'),
    database:   nconf.get('dnmame'),
    connectionLimit: nconf.get('dbmaxconn'),
    acquireTimeout: 300000
});


var get_balances_max = nconf.get('get_balances_max');
var get_accounts_from_keys_max = nconf.get('get_accounts_from_keys_max');

const rpc = new RPCServer({
    wss: {
        port: nconf.get('httpport'),
        host: nconf.get('httphost')
    }
});

rpc.on('listening', () => {
    console.log('Listening on ' + nconf.get('httphost') + ':' + nconf.get('httpport'));
});


rpc.on('connection', (socket, req) => {
    console.log(`${socket.id} connected!`);
});



rpc.methods.set('get_balances', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        console.log('get_balances');
        if( params.reqid == undefined ) {
            reject(new Error('Mising argument: reqid'));
        }    
        else if( params.network == undefined ) {
            reject(new Error('Mising argument: network'));
        }
        else if( params.accounts == undefined ) {
            reject(new Error('Mising argument: accounts'));
        }
        else if( typeof params.accounts !== 'object' || !Array.isArray(params.accounts) ) {
            reject(new Error('accounts must be an array'));
        }
        else if( params.accounts.length > get_balances_max ) {
            reject(new Error('Too many accounts. Maximum: ' + get_balances_max + ', requested: ' + params.accounts.length));
        }
        else {
            pool.getConnection()
                .then(conn => {
                    (async () => {
                        try {
                            let netcnt = await conn.query(
                                'SELECT count(*) as cnt FROM NETWORKS where network=?', [params.network]);
                            
                            if( netcnt[0].cnt == 0 ) {
                                reject(new Error('Invalid network: ' + params.network));
                            }
                            else {
                                resolve();
                                
                                for(let i=0; i<params.accounts.length; i++) {
                                    let acc = params.accounts[i];
                                    let tokens = await conn.query
                                    ('SELECT contract, currency, CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' +
                                     'FROM CURRENCY_BAL WHERE network=? AND account_name=?',
                                     [params.network, acc]);

                                    socket.notify('reqdata', {
                                        'method': 'get_balances',
                                        'reqid': params.reqid,
                                        'data': {account: acc, balances: tokens}});
                                }

                                socket.notify('reqdata', {
                                    'method': 'get_balances',
                                    'reqid': params.reqid,
                                    'end': true});
                            }
                        }
                        catch(err) {
                            reject(err);
                        }
                        conn.release();
                    })();
                });
        }
    });
});




rpc.methods.set('get_accounts_from_keys', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        console.log('get_accounts_from_keys');
        if( params.reqid == undefined ) {
            reject(new Error('Mising argument: reqid'));
        }    
        else if( params.network == undefined ) {
            reject(new Error('Mising argument: network'));
        }
        else if( params.keys == undefined ) {
            reject(new Error('Mising argument: keys'));
        }
        else if( typeof params.keys !== 'object' || !Array.isArray(params.keys) ) {
            reject(new Error('keys must be an array'));
        }
        else if( params.keys.length > get_accounts_from_keys_max ) {
            reject(new Error('Too many keys. Maximum: ' + get_accounts_from_keys_max + ', requested: ' + params.keys.length));
        }
        else {
            pool.getConnection()
                .then(conn => {
                    (async () => {
                        try {
                            let netcnt = await conn.query(
                                'SELECT count(*) as cnt FROM NETWORKS where network=?', [params.network]);
                            
                            if( netcnt[0].cnt == 0 ) {
                                reject(new Error('Invalid network: ' + params.network));
                            }
                            else {
                                resolve();

                                try {
                                    for(let i=0; i<params.keys.length; i++) {
                                        let key = params.keys[i];
                                        if( key.substr(0, 3) === 'EOS') { /* convert from legacy format */
                                            let k = Numeric.stringToPublicKey(key);
                                            key = Numeric.publicKeyToString(k);
                                        }
                                        
                                        await new Promise( (resolve, reject) => {
                                            conn.queryStream('SELECT account_name, perm, weight FROM AUTH_KEYS ' +
                                                             'WHERE network=? AND pubkey=?', [params.network, key])
                                                .on("error", err => {
                                                    console.error(err);
                                                    reject();
                                                })
                                                .on("data", row => {
                                                    row.pubkey = params.keys[i];
                                                    socket.notify('reqdata', {
                                                        'method': 'get_accounts_from_keys',
                                                        'reqid': params.reqid,
                                                        'data': row});
                                                })
                                                .on("end", () => {
                                                    resolve();
                                                });
                                        });
                                    }
                                }
                                catch(err) {
                                    console.error(err);
                                }

                                socket.notify('reqdata', {
                                    'method': 'get_accounts_from_keys',
                                    'reqid': params.reqid,
                                    'end': true});
                            }
                        }
                        catch(err) {
                            reject(err);
                        }
                        conn.release();
                    })();
                });
        }
    });
});




