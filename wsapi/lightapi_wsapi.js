"use strict";

const mariadb   = require('mariadb');
var nconf = require('nconf');
const RPCServer = require('jsonrpc2-ws').Server;
const Numeric = require('eosjs/dist/eosjs-numeric');

nconf.argv();

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


rpc.methods.set('get_networks', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        // console.log('get_networks');
        pool.getConnection()
            .then(conn => {
                conn.query('SELECT NETWORKS.network, chainid, description, systoken, decimals, production, ' +
                           'TIME_TO_SEC(TIMEDIFF(UTC_TIMESTAMP(), block_time)) as sync, ' +
                           'block_num, block_time ' +
                           'FROM NETWORKS JOIN SYNC ON NETWORKS.network=SYNC.network')
                    .then((rows) => {
                        let ret = {};
                        for(let i=0; i<rows.length; i++) {
                            ret[rows[i].network] = rows[i];
                        }
                        resolve(ret);
                    })
                    .catch(err => {
                        console.log(err); 
                        reject(err);
                    });
                conn.release();
            });
    });
});

                            
rpc.methods.set('get_accounts_from_keys', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        // console.log('get_accounts_from_keys');
        if( params.reqid == undefined ) {
            reject(new Error('Missing argument: reqid'));
        }    
        else if( params.network == undefined ) {
            reject(new Error('Missing argument: network'));
        }
        else if( params.keys == undefined ) {
            reject(new Error('Missing argument: keys'));
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

                                let status = 200;
                                let errstring = null;
                                
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
                                    status = 500;
                                    errstring = err;
                                }

                                socket.notify('reqdata', {
                                    'method': 'get_accounts_from_keys',
                                    'reqid': params.reqid,
                                    'end': true,
                                    'status': status,
                                    'error': errstring});
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



rpc.methods.set('get_balances', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        // console.log('get_balances');
        if( params.reqid == undefined ) {
            reject(new Error('Missing argument: reqid'));
        }    
        else if( params.network == undefined ) {
            reject(new Error('Missing argument: network'));
        }
        else if( params.accounts == undefined ) {
            reject(new Error('Missing argument: accounts'));
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

                                let status = 200;
                                let errstring = null;

                                try {
                                    for(let i=0; i<params.accounts.length; i++) {
                                        let acc = params.accounts[i];
                                        let balances = await conn.query
                                        ('SELECT contract, currency, CAST(amount AS CHAR ASCII) AS amount, decimals ' +
                                         'FROM CURRENCY_BAL WHERE network=? AND account_name=?',
                                         [params.network, acc]);

                                        let ret_balances = new Array();
                                        for(let j=0; j<balances.length; j++) {
                                            let b = balances[j];
                                            ret_balances.push({contract: b.contract,
                                                               currency: b.currency,
                                                               amount: apply_decimals(b.amount, b.decimals)});
                                        }
                                        
                                        socket.notify('reqdata', {
                                            'method': 'get_balances',
                                            'reqid': params.reqid,
                                            'data': {account: acc, balances: ret_balances}});
                                    }
                                }
                                catch(err) {
                                    console.error(err);
                                    status = 500;
                                    errstring = err;
                                }
                                
                                socket.notify('reqdata', {
                                    'method': 'get_balances',
                                    'reqid': params.reqid,
                                    'end': true,
                                    'status': status,
                                    'error': errstring});
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



rpc.methods.set('get_token_holders', async (socket, params) => {
    return new Promise( (resolve, reject) => {
        // console.log('get_token_holders');
        if( params.reqid == undefined ) {
            reject(new Error('Missing argument: reqid'));
        }    
        else if( params.network == undefined ) {
            reject(new Error('Missing argument: network'));
        }
        else if( params.contract == undefined ) {
            reject(new Error('Missing argument: contract'));
        }
        else if( params.currency == undefined ) {
            reject(new Error('Missing argument: currency'));
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

                                let status = 200;
                                let errstring = null;

                                try {
                                    await new Promise( (resolve, reject) => {
                                        conn.queryStream('SELECT account_name AS acc, ' +
                                                         'CAST(amount AS CHAR ASCII) AS amount, decimals ' +
                                                         'FROM CURRENCY_BAL WHERE network=? AND contract=? AND currency=?',
                                                         [params.network, params.contract, params.currency])
                                            .on("error", err => {
                                                console.error(err);
                                                reject();
                                            })
                                            .on("data", row => {
                                                socket.notify('reqdata', {
                                                    'method': 'get_token_holders',
                                                    'reqid': params.reqid,
                                                    'data': {account: row.acc, amount: apply_decimals(row.amount, row.decimals)}});
                                            })
                                            .on("end", () => {
                                                resolve();
                                            });
                                    });
                                    
                                }
                                catch(err) {
                                    console.error(err);
                                    status = 500;
                                    errstring = err;
                                }
                                
                                socket.notify('reqdata', {
                                    'method': 'get_token_holders',
                                    'reqid': params.reqid,
                                    'end': true,
                                    'status': status,
                                    'error': errstring});
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



// =========== utility functions ===========

function apply_decimals(amt, decimals) {
    if( decimals == 0 ) {
        return amt;
    }
    
    let pos = amt.indexOf('.');
    if( pos < 0 ) {
        amt = amt.concat('.');
    } else {
        decimals -= amt.length - pos - 1;
        if( decimals < 0 ) { decimals = 0; }
    }
    return amt.concat('0'.repeat(decimals));
}








