CREATE DATABASE lightapi;

CREATE USER 'lightapi'@'localhost' IDENTIFIED BY 'ce1Shish';
GRANT ALL ON lightapi.* TO 'lightapi'@'localhost';
grant SELECT on lightapi.* to 'lightapiro'@'%' identified by 'lightapiro';

use lightapi;

CREATE TABLE NETWORKS
(
 network           VARCHAR(15) PRIMARY KEY,
 chainid           VARCHAR(64) NOT NULL,
 description       VARCHAR(256) NOT NULL,
 systoken          VARCHAR(7) NOT NULL,
 decimals          TINYINT NOT NULL,
 production        TINYINT NOT NULL DEFAULT 1,
 rex_enabled       TINYINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;


CREATE TABLE SYNC
(
 network           VARCHAR(15) PRIMARY KEY,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 irreversible      BIGINT NOT NULL 
) ENGINE=InnoDB;



CREATE TABLE CURRENCY_BAL
 (
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL,
 decimals          TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX CURRENCY_BAL_I01 ON CURRENCY_BAL (network, account_name, contract, currency);
CREATE INDEX CURRENCY_BAL_I02 ON CURRENCY_BAL (network, contract, currency, amount);
CREATE INDEX CURRENCY_BAL_I03 ON CURRENCY_BAL (network, currency, contract);



CREATE TABLE AUTH_THRESHOLDS
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 threshold         INT NOT NULL,
 parent            VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX AUTH_THRESHOLDS_I01 ON AUTH_THRESHOLDS (network, account_name, perm);


CREATE TABLE AUTH_KEYS
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 pubkey            VARCHAR(256) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX AUTH_KEYS_I01 ON AUTH_KEYS (network, account_name, perm);
CREATE INDEX AUTH_KEYS_I02 ON AUTH_KEYS (network, pubkey(32));
CREATE INDEX AUTH_KEYS_I03 ON AUTH_KEYS (pubkey(32));


CREATE TABLE AUTH_ACC
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 actor             VARCHAR(13) NOT NULL,
 permission        VARCHAR(13) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX AUTH_ACC_I01 ON AUTH_ACC (network, account_name, perm, actor, permission);
CREATE INDEX AUTH_ACC_I02 ON AUTH_ACC (network, actor);


CREATE TABLE AUTH_WAITS
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 wait              INT NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX AUTH_WAITS_I01 ON AUTH_WAITS (network, account_name, perm);


CREATE TABLE LINKAUTH
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 code              VARCHAR(13) NOT NULL,
 type              VARCHAR(13) NOT NULL,
 requirement       VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX LINKAUTH_I01 ON LINKAUTH (network, account_name, code, type);


CREATE TABLE DELBAND
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 del_from          VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX DELBAND_I01 ON DELBAND (network, account_name, del_from);
CREATE INDEX DELBAND_I02 ON DELBAND (network, del_from);


CREATE TABLE CODEHASH
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 code_hash         VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX CODEHASH_I01 ON CODEHASH (network, account_name);
CREATE INDEX CODEHASH_I02 ON CODEHASH (network, code_hash);
CREATE INDEX CODEHASH_I03 ON CODEHASH (code_hash);

CREATE TABLE USERRES
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 ram_bytes         BIGINT UNSIGNED NOT NULL,
 weight_sum        BIGINT AS (cpu_weight+net_weight) PERSISTENT
) ENGINE=InnoDB;

CREATE UNIQUE INDEX USERRES_I01 ON USERRES (network, account_name);
CREATE INDEX USERRES_I02 ON USERRES (network, ram_bytes);
CREATE INDEX USERRES_I03 ON USERRES (network, weight_sum);

/* in REX balances, we assume it's 4 decimals because it's hardcoded in system contract */

CREATE TABLE REXFUND
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 balance           DOUBLE PRECISION NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX REXFUND_I01 ON REXFUND (network, account_name);


CREATE TABLE REXBAL
 (
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 vote_stake        DOUBLE PRECISION NOT NULL,
 rex_balance       DOUBLE PRECISION NOT NULL,
 matured_rex       BIGINT UNSIGNED NOT NULL,
 rex_maturities    BLOB NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX REXBAL_I01 ON REXBAL (network, account_name);


CREATE TABLE REXPOOL
 (
 network           VARCHAR(15) NOT NULL PRIMARY KEY,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 total_lent        DOUBLE PRECISION NOT NULL,
 total_unlent      DOUBLE PRECISION NOT NULL,
 total_rent        DOUBLE PRECISION NOT NULL,
 total_lendable    DOUBLE PRECISION NOT NULL,
 total_rex         DOUBLE PRECISION NOT NULL,
 namebid_proceeds  DOUBLE PRECISION NOT NULL,
 loan_num          BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB;



/* ------ Queues of updates before they become irreversible ------ */

CREATE TABLE UPD_CURRENCY_BAL
 (
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL,
 decimals          TINYINT NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_CURRENCY_BAL_I01 ON UPD_CURRENCY_BAL (network, block_num);
CREATE INDEX UPD_CURRENCY_BAL_I02 ON UPD_CURRENCY_BAL (network, account_name);


CREATE TABLE UPD_AUTH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 parent            VARCHAR(13) NOT NULL,
 jsdata            BLOB NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_AUTH_I01 ON UPD_AUTH (network, block_num);
CREATE INDEX UPD_AUTH_I02 ON UPD_AUTH (network, account_name);


CREATE TABLE UPD_LINKAUTH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 code              VARCHAR(13) NOT NULL,
 type              VARCHAR(13) NOT NULL,
 requirement       VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_LINKAUTH_I01 ON UPD_LINKAUTH (network, block_num);
CREATE INDEX UPD_LINKAUTH_I02 ON UPD_LINKAUTH (network, account_name);



CREATE TABLE UPD_DELBAND
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 del_from          VARCHAR(13) NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_DELBAND_I01 ON UPD_DELBAND (network, block_num);
CREATE INDEX UPD_DELBAND_I02 ON UPD_DELBAND (network, account_name);
CREATE INDEX UPD_DELBAND_I03 ON UPD_DELBAND (network, del_from);



CREATE TABLE UPD_CODEHASH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 code_hash         VARCHAR(64) NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_CODEHASH_I01 ON UPD_CODEHASH (network, block_num);
CREATE INDEX UPD_CODEHASH_I02 ON UPD_CODEHASH (network, account_name);


CREATE TABLE UPD_USERRES
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 ram_bytes         BIGINT UNSIGNED NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_USERRES_I01 ON UPD_USERRES (network, block_num);
CREATE INDEX UPD_USERRES_I02 ON UPD_USERRES (network, account_name);


CREATE TABLE UPD_REXFUND
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 balance           DOUBLE PRECISION NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_REXFUND_I01 ON UPD_REXFUND (network, block_num);
CREATE INDEX UPD_REXFUND_I02 ON UPD_REXFUND (network, account_name);



CREATE TABLE UPD_REXBAL
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 vote_stake        DOUBLE PRECISION NOT NULL,
 rex_balance       DOUBLE PRECISION NOT NULL,
 matured_rex       BIGINT UNSIGNED NOT NULL,
 rex_maturities    BLOB NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX UPD_REXBAL_I01 ON UPD_REXBAL (network, block_num);
CREATE INDEX UPD_REXBAL_I02 ON UPD_REXBAL (network, account_name);



CREATE TABLE UPD_REXPOOL
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 total_lent        DOUBLE PRECISION NOT NULL,
 total_unlent      DOUBLE PRECISION NOT NULL,
 total_rent        DOUBLE PRECISION NOT NULL,
 total_lendable    DOUBLE PRECISION NOT NULL,
 total_rex         DOUBLE PRECISION NOT NULL,
 namebid_proceeds  DOUBLE PRECISION NOT NULL,
 loan_num          BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_REXPOOL_I01 ON UPD_REXPOOL (network, block_num);


/* ------ tables updated by cron jobs ------ */



CREATE TABLE HOLDERCOUNTS
(
 network           VARCHAR(15) NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 holders           BIGINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX HOLDERCOUNTS_I01 ON HOLDERCOUNTS (network, contract, currency);

