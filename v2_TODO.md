# EOSIO LightAPI version 2: development plan

## Chronicle data feed

Instead of ZMQ plugin, Chronicle Receiver will feed the new database:

https://github.com/EOSChronicleProject/eos-chronicle

It delivers contract table deltas, so token balances will be tracked
more precisely, independent from ABI compatibility.

The new version of Light API should handle forks better. The tables as
in v1 should be populated only after the data becomes
irreversible. There should be new tables for reversible blocks data. The
API should merge data from reversible and irreversible tables.


## New features

* RAM purchase tracking: who bought how much RAM for each account.

* Code hash indexing: fiding contracts with the same code will be
  easier.

* Bandwidth delegation tracking: who delegated how much CPU/NET to a
  particular account.

* Support for R1 and K1 keys. The API should report K1 keys in legacy
  format (EOSxxx), and optionally in new format.

* Token adoption reports every million blocks: number of holders for
  each token, and Gini coefficient. These reports will be stored for the
  whole history of tokens.

* Probably custom token staking contracts will be taken into account for
  adoption reports. This needs to be communicated with each project
  individually.








