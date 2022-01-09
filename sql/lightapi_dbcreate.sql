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



