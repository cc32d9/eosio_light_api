CREATE DATABASE tokenapi;

CREATE USER 'tokenapi'@'localhost' IDENTIFIED BY 'ce1Shish';
GRANT ALL ON tokenapi.* TO 'tokenapi'@'localhost';
grant SELECT on tokenapi.* to 'tokenapiro'@'%' identified by 'tokenapiro';

use tokenapi;


CREATE TABLE TOKENAPI_LATEST_RESOURCE
(
 account_name      VARCHAR(13) PRIMARY KEY,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL,
 cpu_weight        DOUBLE PRECISION NOT NULL,
 net_weight        DOUBLE PRECISION NOT NULL,
 ram_quota         INTEGER NOT NULL,
 ram_usage         INTEGER NOT NULL
) ENGINE=InnoDB;


CREATE TABLE TOKENAPI_LATEST_CURRENCY
 (
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL,
 issuer            VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX TOKENAPI_LATEST_CURRENCY_I01 ON TOKENAPI_LATEST_CURRENCY (account_name, issuer, currency);
CREATE INDEX TOKENAPI_LATEST_CURRENCY_I02 ON TOKENAPI_LATEST_CURRENCY (issuer, currency, amount);
CREATE INDEX TOKENAPI_LATEST_CURRENCY_I03 ON TOKENAPI_LATEST_CURRENCY (currency, issuer);

