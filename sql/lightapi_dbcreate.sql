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







/* ------ tables updated by cron jobs ------ */



CREATE TABLE HOLDERCOUNTS
(
 network           VARCHAR(15) NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 holders           BIGINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX HOLDERCOUNTS_I01 ON HOLDERCOUNTS (network, contract, currency);



/* ------ FIO specific tables ------ */

CREATE TABLE FIO_NAME
(
 network           VARCHAR(15) NOT NULL,
 id                BIGINT NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 fio_name          VARCHAR(64) NOT NULL,
 fio_domain        VARCHAR(62) NOT NULL,
 expiration        DATETIME NOT NULL,
 bdlelgcntdwn      BIGINT NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX FIO_NAME_I01 ON FIO_NAME (network, id);
CREATE INDEX FIO_NAME_I02 ON FIO_NAME (network, account_name);
CREATE INDEX FIO_NAME_I03 ON FIO_NAME (network, fio_name, fio_domain);
CREATE INDEX FIO_NAME_I04 ON FIO_NAME (network, fio_domain, fio_name);
CREATE INDEX FIO_NAME_I05 ON FIO_NAME (network, expiration);


CREATE TABLE FIO_TOKENPUBADDR
(
 network           VARCHAR(15) NOT NULL,
 name_id           BIGINT NOT NULL,
 token_code        VARCHAR(10) NOT NULL,
 chain_code        VARCHAR(10) NOT NULL,
 public_address    VARCHAR(128) NOT NULL,
 FOREIGN KEY (network, name_id)
     REFERENCES FIO_NAME(network, id)
     ON DELETE CASCADE
) ENGINE=InnoDB;
 
CREATE INDEX FIO_TOKENPUBADDR_I01 ON FIO_TOKENPUBADDR (network, public_address);


CREATE TABLE FIO_DOMAIN
(
 network           VARCHAR(15) NOT NULL,
 id                BIGINT NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 fio_domain        VARCHAR(62) NOT NULL,
 expiration        DATETIME NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX FIO_DOMAIN_I01 ON FIO_DOMAIN (network, id);
CREATE INDEX FIO_DOMAIN_I02 ON FIO_DOMAIN (network, account_name);
CREATE INDEX FIO_DOMAIN_I04 ON FIO_DOMAIN (network, fio_domain);
CREATE INDEX FIO_DOMAIN_I05 ON FIO_DOMAIN (network, expiration);




CREATE TABLE FIO_CLIENTKEY
(
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 clientkey         VARCHAR(128) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX FIO_CLIENTKEY_I01 ON FIO_CLIENTKEY (network, account_name);
CREATE INDEX FIO_CLIENTKEY_I02 ON FIO_CLIENTKEY (network, clientkey);



CREATE TABLE UPD_FIO_NAME
 (
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 name_id           BIGINT NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 fio_name          VARCHAR(64) NOT NULL,
 fio_domain        VARCHAR(62) NOT NULL,
 expiration        DATETIME NOT NULL,
 bdlelgcntdwn      BIGINT NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_FIO_NAME_I01 ON UPD_FIO_NAME (network, block_num);
CREATE INDEX UPD_FIO_NAME_I02 ON UPD_FIO_NAME (network, account_name);


CREATE TABLE UPD_FIO_TOKENPUBADDR
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 name_id           BIGINT NOT NULL,
 token_code        VARCHAR(10) NOT NULL,
 chain_code        VARCHAR(10) NOT NULL,
 public_address    VARCHAR(128) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_FIO_TOKENPUBADDR_I01 ON UPD_FIO_TOKENPUBADDR (network, block_num);


CREATE TABLE UPD_FIO_DOMAIN
 (
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 domain_id         BIGINT NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 fio_domain        VARCHAR(62) NOT NULL,
 expiration        DATETIME NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_FIO_DOMAIN_I01 ON UPD_FIO_DOMAIN (network, block_num);
CREATE INDEX UPD_FIO_DOMAIN_I02 ON UPD_FIO_DOMAIN (network, account_name);



CREATE TABLE UPD_FIO_CLIENTKEY
 (
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 network           VARCHAR(15) NOT NULL,
 account_name      VARCHAR(13) NOT NULL,
 clientkey         VARCHAR(128) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;


CREATE INDEX UPD_FIO_CLIENTKEY_I01 ON UPD_FIO_CLIENTKEY (network, block_num);
CREATE INDEX UPD_FIO_CLIENTKEY_I02 ON UPD_FIO_CLIENTKEY (network, account_name);
