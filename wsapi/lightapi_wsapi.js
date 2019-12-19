"use strict";

const mariadb   = require('mariadb');
var nconf = require('nconf');
const RPCServer = require('jsonrpc2-ws').Server;

nconf.defaults({
    'dbhost':     'localhost',
    'dnmame':     'lightapi',
    'dbuser':     'lightapiro',
    'dbpassword': 'lightapiro',
    'dbmaxconn':  20,
    'httpport':   5010,
    'httphost':   '127.0.0.1',
    'maxaccs':    100
});

nconf.env().argv();

const pool = mariadb.createPool({
    host:       nconf.get('dbhost'),
    user:       nconf.get('dbuser'),
    password:   nconf.get('dbpassword'),
    database:   nconf.get('dnmame'),
    connectionLimit: nconf.get('dbmaxconn')
});


var maxaccs = nconf.get('maxaccs');

const rpc = new RPCServer({
    wss: {
        port: nconf.get('httpport'),
        host: nconf.get('httphost')
    }
});

rpc.on("listening", () => {
    console.log("Listening on " + nconf.get('httphost') + ':' + nconf.get('httpport'));
});


rpc.on("connection", (socket, req) => {
    console.log(`${socket.id} connected!`);
});



rpc.methods.set("get_balances", async (socket, params) => {
    return new Promise( (resolve, reject) => {
        console.log("get_balances");
        if( params.network == undefined ) {
            reject(new Error('Mising argument: network'));
        }
        else if( params.accounts == undefined ) {
            reject(new Error('Mising argument: accounts'));
        }
        else if( typeof params.accounts !== 'object' || !Array.isArray(params.accounts) ) {
            reject(new Error('Wrong type: accounts'));
        }
        else if( params.accounts.length > maxaccs ) {
            reject(new Error('Too many accounts. Maximum: ' + maxaccs + ', requested: ' + params.accounts.length));
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
                                let ret = [];
                                for(let i=0; i<params.accounts.length; i++) {
                                    let acc = params.accounts[i];
                                    let tokens = await conn.query
                                    ('SELECT contract, currency, CAST(amount AS DECIMAL(48,24)) AS amount, decimals ' +
                                     'FROM CURRENCY_BAL WHERE network=? AND account_name=?',
                                     [params.network, acc]);
                                    
                                    ret.push({account: acc, balances: tokens});
                                }
                                resolve(ret);
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



