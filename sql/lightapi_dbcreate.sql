CREATE DATABASE lightapi;

CREATE USER 'lightapi'@'localhost' IDENTIFIED BY 'ce1Shish';
GRANT ALL ON lightapi.* TO 'lightapi'@'localhost';
grant SELECT on lightapi.* to 'lightapiro'@'%' identified by 'lightapiro';

use lightapi;


CREATE TABLE LIGHTAPI_LATEST_RESOURCE
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


CREATE TABLE LIGHTAPI_LATEST_CURRENCY
 (
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL,
 contract            VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_LATEST_CURRENCY_I01 ON LIGHTAPI_LATEST_CURRENCY (account_name, contract, currency);
CREATE INDEX LIGHTAPI_LATEST_CURRENCY_I02 ON LIGHTAPI_LATEST_CURRENCY (contract, currency, amount);
CREATE INDEX LIGHTAPI_LATEST_CURRENCY_I03 ON LIGHTAPI_LATEST_CURRENCY (currency, contract);



CREATE TABLE LIGHTAPI_AUTH_THRESHOLDS
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 threshold         INT NOT NULL,
 parent            VARCHAR(13),
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 trx_id            VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_THRESHOLDS_I01 ON LIGHTAPI_AUTH_THRESHOLDS (account_name, perm);


CREATE TABLE LIGHTAPI_AUTH_KEYS
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 pubkey            VARCHAR(53) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_KEYS_I01 ON LIGHTAPI_AUTH_KEYS (account_name, perm, pubkey);
CREATE INDEX LIGHTAPI_AUTH_KEYS_I02 ON LIGHTAPI_AUTH_KEYS (pubkey);


CREATE TABLE LIGHTAPI_AUTH_ACC
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 actor             VARCHAR(13) NOT NULL,
 permission        VARCHAR(13) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LIGHTAPI_AUTH_ACC_I01 ON LIGHTAPI_AUTH_ACC (account_name, perm, actor, permission);
CREATE INDEX LIGHTAPI_AUTH_ACC_I02 ON LIGHTAPI_AUTH_ACC (actor);
