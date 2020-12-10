# ANYToken stake
ANYToken stake smart contract

## install @openzeppelin/contracts

```shell
npm install
```

## modify

1. edit solidity source in `internal` directory
2. flatten solidity source in `internal` directory to `contracts` directory

```shell
truffle-flattener internal/Stake.sol | sed '/SPDX-License-Identifier:/d' | sed 1i'// SPDX-License-Identifier: MIT' > contracts/Stake.sol
```

## compile

```shell
truffle compile
```

## deploy

```shell
truffle migrate
```

## bytecode

use remix: <https://remix.ethereum.org/#optimize=true&evmVersion=null&version=soljson-v0.5.4+commit.9549d8ff.js&runs=200>

## how to deploy node stake contract

1. deploy `NodeStake` (assume contract address is `nodestake_address`)
2. deploy `RewardPool` (deploy twice, specify first param of contructor to `nodestake_address`)
3. call `setRewardPool` (call twice to set reward pool of node type 1 and 2)
