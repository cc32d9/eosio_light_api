use lightapi;

CREATE TABLE %%_CURRENCY_BAL
 (
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL,
 decimals          TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_CURRENCY_BAL_I01 ON %%_CURRENCY_BAL (account_name, contract, currency);
CREATE INDEX %%_CURRENCY_BAL_I02 ON %%_CURRENCY_BAL (contract, currency, amount);
CREATE INDEX %%_CURRENCY_BAL_I03 ON %%_CURRENCY_BAL (currency, contract);



CREATE TABLE %%_AUTH_THRESHOLDS
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 threshold         INT NOT NULL,
 parent            VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_AUTH_THRESHOLDS_I01 ON %%_AUTH_THRESHOLDS (account_name, perm);


CREATE TABLE %%_AUTH_KEYS
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 pubkey            VARCHAR(256) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_AUTH_KEYS_I01 ON %%_AUTH_KEYS (account_name, perm);
CREATE INDEX %%_AUTH_KEYS_I02 ON %%_AUTH_KEYS (pubkey(32));


CREATE TABLE %%_AUTH_ACC
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 actor             VARCHAR(13) NOT NULL,
 permission        VARCHAR(13) NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_AUTH_ACC_I01 ON %%_AUTH_ACC (account_name, perm, actor, permission);
CREATE INDEX %%_AUTH_ACC_I02 ON %%_AUTH_ACC (actor);


CREATE TABLE %%_AUTH_WAITS
(
 account_name      VARCHAR(13) NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 wait              INT NOT NULL,
 weight            INT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_AUTH_WAITS_I01 ON %%_AUTH_WAITS (account_name, perm);


CREATE TABLE %%_LINKAUTH
(
 account_name      VARCHAR(13) NOT NULL,
 code              VARCHAR(13) NOT NULL,
 type              VARCHAR(13) NOT NULL,
 requirement       VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_LINKAUTH_I01 ON %%_LINKAUTH (account_name, code, type);


CREATE TABLE %%_DELBAND
(
 account_name      VARCHAR(13) NOT NULL,
 del_from          VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_DELBAND_I01 ON %%_DELBAND (account_name, del_from);
CREATE INDEX %%_DELBAND_I02 ON %%_DELBAND (del_from);


CREATE TABLE %%_CODEHASH
(
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 code_hash         VARCHAR(64) NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_CODEHASH_I01 ON %%_CODEHASH (account_name);
CREATE INDEX %%_CODEHASH_I02 ON %%_CODEHASH (code_hash);


CREATE TABLE %%_USERRES
(
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 ram_bytes         BIGINT UNSIGNED NOT NULL,
 weight_sum        BIGINT AS (cpu_weight+net_weight) PERSISTENT
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_USERRES_I01 ON %%_USERRES (account_name);
CREATE INDEX %%_USERRES_I02 ON %%_USERRES (ram_bytes);
CREATE INDEX %%_USERRES_I03 ON %%_USERRES (weight_sum);

/* in REX balances, we assume it's 4 decimals because it's hardcoded in system contract */

CREATE TABLE %%_REXFUND
(
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 balance           DOUBLE PRECISION NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_REXFUND_I01 ON %%_REXFUND (account_name);


CREATE TABLE %%_REXBAL
 (
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 vote_stake        DOUBLE PRECISION NOT NULL,
 rex_balance       DOUBLE PRECISION NOT NULL,
 matured_rex       BIGINT UNSIGNED NOT NULL,
 rex_maturities    BLOB NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_REXBAL_I01 ON %%_REXBAL (account_name);


CREATE TABLE %%_REXPOOL
 (
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

CREATE TABLE %%_UPD_CURRENCY_BAL
 (
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 amount            DOUBLE PRECISION NOT NULL,
 decimals          TINYINT NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX %%_UPD_CURRENCY_BAL_I01 ON %%_UPD_CURRENCY_BAL (block_num);
CREATE INDEX %%_UPD_CURRENCY_BAL_I02 ON %%_UPD_CURRENCY_BAL (account_name);


CREATE TABLE %%_UPD_AUTH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 perm              VARCHAR(13) NOT NULL,
 parent            VARCHAR(13) NOT NULL,
 jsdata            MEDIUMBLOB NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_AUTH_I01 ON %%_UPD_AUTH (block_num);
CREATE INDEX %%_UPD_AUTH_I02 ON %%_UPD_AUTH (account_name);


CREATE TABLE %%_UPD_LINKAUTH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 code              VARCHAR(13) NOT NULL,
 type              VARCHAR(13) NOT NULL,
 requirement       VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_LINKAUTH_I01 ON %%_UPD_LINKAUTH (block_num);
CREATE INDEX %%_UPD_LINKAUTH_I02 ON %%_UPD_LINKAUTH (account_name);



CREATE TABLE %%_UPD_DELBAND
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 del_from          VARCHAR(13) NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;


CREATE INDEX %%_UPD_DELBAND_I01 ON %%_UPD_DELBAND (block_num);
CREATE INDEX %%_UPD_DELBAND_I02 ON %%_UPD_DELBAND (account_name);
CREATE INDEX %%_UPD_DELBAND_I03 ON %%_UPD_DELBAND (del_from);



CREATE TABLE %%_UPD_CODEHASH
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 code_hash         VARCHAR(64) NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_CODEHASH_I01 ON %%_UPD_CODEHASH (block_num);
CREATE INDEX %%_UPD_CODEHASH_I02 ON %%_UPD_CODEHASH (account_name);


CREATE TABLE %%_UPD_USERRES
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 cpu_weight        BIGINT UNSIGNED NOT NULL,
 net_weight        BIGINT UNSIGNED NOT NULL,
 ram_bytes         BIGINT UNSIGNED NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_USERRES_I01 ON %%_UPD_USERRES (block_num);
CREATE INDEX %%_UPD_USERRES_I02 ON %%_UPD_USERRES (account_name);


CREATE TABLE %%_UPD_REXFUND
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 balance           DOUBLE PRECISION NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_REXFUND_I01 ON %%_UPD_REXFUND (block_num);
CREATE INDEX %%_UPD_REXFUND_I02 ON %%_UPD_REXFUND (account_name);



CREATE TABLE %%_UPD_REXBAL
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 account_name      VARCHAR(13) NOT NULL,
 block_num         BIGINT NOT NULL,
 block_time        DATETIME NOT NULL,
 vote_stake        DOUBLE PRECISION NOT NULL,
 rex_balance       DOUBLE PRECISION NOT NULL,
 matured_rex       BIGINT UNSIGNED NOT NULL,
 rex_maturities    BLOB NOT NULL,
 deleted           TINYINT NOT NULL
) ENGINE=InnoDB;

CREATE INDEX %%_UPD_REXBAL_I01 ON %%_UPD_REXBAL (block_num);
CREATE INDEX %%_UPD_REXBAL_I02 ON %%_UPD_REXBAL (account_name);



CREATE TABLE %%_UPD_REXPOOL
(
 id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
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


CREATE INDEX %%_UPD_REXPOOL_I01 ON %%_UPD_REXPOOL (block_num);


/* ------ tables updated by cron jobs ------ */



CREATE TABLE %%_HOLDERCOUNTS
(
 contract          VARCHAR(13) NOT NULL,
 currency          VARCHAR(8) NOT NULL,
 holders           BIGINT NOT NULL
) ENGINE=InnoDB;

CREATE UNIQUE INDEX %%_HOLDERCOUNTS_I01 ON %%_HOLDERCOUNTS (contract, currency);

