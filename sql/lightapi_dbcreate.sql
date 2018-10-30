CREATE DATABASE lightapi;

CREATE USER 'lightapi'@'localhost' IDENTIFIED BY 'ce1Shish';
GRANT ALL ON lightapi.* TO 'lightapi'@'localhost';
grant SELECT on lightapi.* to 'lightapiro'@'%' identified by 'lightapiro';

use lightapi;

CREATE TABLE LIGHTAPI_NETWORKS
(
 network           VARCHAR(15) PRIMARY KEY,
 chainid           VARCHAR(64) NOT NULL,
 description       VARCHAR(256) NOT NULL,
 systoken          VARCHAR(7) NOT NULL,
 decimals          SMALLINT NOT NULL
) ENGINE=InnoDB;


CREATE TABLE LIGHTAPI_LATEST_RESOURCE
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL,
 cpu_weight        BIGINT NOT NULL,
 net_weight        BIGINT NOT NULL,
 ram_quota         INTEGER NOT NULL,
 ram_usage         INTEGER NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_LATEST_RESOURCE_I01 ON LIGHTAPI_LATEST_RESOURCE(network, account_name);


CREATE TABLE LIGHTAPI_LATEST_CURRENCY
 (
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_LATEST_CURRENCY_I01 ON LIGHTAPI_LATEST_CURRENCY (network, account_name, contract, currency);
CREATE INDEX LIGHTAPI_LATEST_CURRENCY_I02 ON LIGHTAPI_LATEST_CURRENCY (network, contract, currency, amount);
CREATE INDEX LIGHTAPI_LATEST_CURRENCY_I03 ON LIGHTAPI_LATEST_CURRENCY (network, currency, contract);



CREATE TABLE LIGHTAPI_AUTH_THRESHOLDS
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 threshold         INT NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_THRESHOLDS_I01 ON LIGHTAPI_AUTH_THRESHOLDS (network, account_name, perm);


CREATE TABLE LIGHTAPI_AUTH_KEYS
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 pubkey            VARCHAR(53) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_KEYS_I01 ON LIGHTAPI_AUTH_KEYS (network, account_name, perm, pubkey);
CREATE INDEX LIGHTAPI_AUTH_KEYS_I02 ON LIGHTAPI_AUTH_KEYS (network, pubkey);
CREATE INDEX LIGHTAPI_AUTH_KEYS_I03 ON LIGHTAPI_AUTH_KEYS (pubkey);


CREATE TABLE LIGHTAPI_AUTH_ACC
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 actor             VARCHAR(13) NOT NULL,
 permission        VARCHAR(13) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_ACC_I01 ON LIGHTAPI_AUTH_ACC (network, account_name, perm, actor, permission);
CREATE INDEX LIGHTAPI_AUTH_ACC_I02 ON LIGHTAPI_AUTH_ACC (network, actor);
