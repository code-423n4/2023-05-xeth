# xETH Invitational contest details

- Total Prize Pool: $35,000 USDC
  - HM awards: $15,810 USDC
  - QA report awards: $1,860 USDC
  - Gas report awards: $930 USDC
  - Judge awards: 7,000 USDC
  - Lookout awards: $2,400 USDC
  - Scout awards: $500 USDC
  - Mitigation review contest: $6,500 USDC
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2023-05-xeth-versus-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts May 12, 2023 20:00 UTC
- Ends May 15, 2023 20:00 UTC

## Automated Findings / Publicly Known Issues

Automated findings output for the contest can be found [here](https://gist.github.com/romeroadrian/26e1fda576f5a127e69ad3595c581b87 within 24 hours of contest opening.

_Note for C4 wardens: Anything included in the automated findings output is considered a publicly known issue and is ineligible for awards._

------

# Overview

> LSD (Liquid Staking Derivative) Aggregator as a Service.

# Scope

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [src/AMO2.sol](https://github.com/code-423n4/2023-05-xeth/blob/main/src/AMO2.sol) | 330 | AMO Contract for xETH | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and Curve |
| [src/CVXStaker.sol](https://github.com/code-423n4/2023-05-xeth/blob/main/src/CVXStaker.sol) | 142 | Staking xETH-stETH LP tokens to CVX, used by the AMO | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and Curve |
| [src/wxETH.sol](https://github.com/code-423n4/2023-05-xeth/blob/main/src/wxETH.sol) | 113 | wxETH is xETH staking to get rewards | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and [`solmate/`](lib/solmate) |
| [src/xETH.sol](https://github.com/code-423n4/2023-05-xeth/blob/main/src/xETH.sol) | 51 | xETH is a mintable ERC20 token with pausing | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) |

`src/interfaces` is included.

`src/archive` is **Out of Scope**.

## Description

### xETH

xETH is the ERC20 token of this project, which will be paired against stETH to open up a curve pool.

It has Access Control, so anyone with MINTER_ROLE can mint xETH. In this specific case, MINTER_ROLE is assigned to AMO contract. For minting / burning xETH from the Curve Pool.

This contract has pausable transfers as well. In case of any emergency.

### wxETH

wxETH is the staking contract of xETH. where holders of xETH can stake wxETH to earn some yield on it.

It follows a drip mechanism, where the owner has to add certain locked funds and they are distributed block by block to the holders (as an exchangeRate adjustment)

### AMO2

AMO mints and burns xETH to deposit it into the curve pool and staking the LP into the convex reward pool.

rebalanceUp = burn
rebalanceDown = mint

it mints when xETH %age in pool is below a certain threshold. it burns when xETH %age is above a certain threshold.

The amounts of lpBurn and xETH mint comes from an offchain bot called defender. But we rely on a contract based quote (with a certain slippage) to cap it and find the best quote

### CVXStaker

It is pretty much a fork of aura staker: <https://etherscan.io/address/0xDaAC0A9818aFA6f8Fb4672Dc8284940B169c96e8> and it stakes lp token into a convex pool and helps in recovery of rewards, withdrawals, etc.

### Rebalance Defender (not a contract)

It is a role assigned to an off-chain bot that provides quotes for rebalancing up and down. It's quote is checked against a quote provided by the AMO contract with higher slippage to ensure that the provided quote isn't malicious.

## Setup Instructions

The tests depend on mainnet curve contracts, which will require you to run tests in forking mode with an RPC.

We used alchemy while building the protocol and hence an example of the same is added. Please replace `[ALCHEMY_API_KEY]` variable before running the commands below.

```bash
git submodule update --init --recursive  ## initialize submodule dependencies
npm install ## install development dependencies
forge build
forge test -vvv -f https://eth-mainnet.g.alchemy.com/v2/[ALCHEMY_API_KEY]
```

### Tests

You can run tests by using the following command (can also be used with Infura's mainnet RPC URL):

```bash
forge test -vvv -f https://eth-mainnet.g.alchemy.com/v2/[ALCHEMY_API_KEY]
```

Please note that the tests for this codebase are _NON EXHAUSTIVE_. They do not cover every single case of the protocol, but do help in development and testing certain features / aspects of the code.


## Scoping Details 
```
- If you have a public code repo, please share it here:  
- How many contracts are in scope?: 4  
- Total SLoC for these contracts?:  636
- How many external imports are there?:  3
- How many separate interfaces and struct definitions are there for the contracts within scope?:  3+4
- Does most of your code generally use composition or inheritance?:   Composition
- How many external calls?:   5
- What is the overall line coverage percentage provided by your tests?:  68
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?:   false
- Please describe required context:   n/a
- Does it use an oracle?:  no
- Does the token conform to the ERC20 standard?:  true
- Are there any novel or unique curve logic or mathematical models?: It doesn't really use any novel logic, it does some calculations on top of a curve pool for adding/removing liquidity. that's it.
- Does it use a timelock function?:  
- Is it an NFT?: 
- Does it have an AMM?:   true
- Is it a fork of a popular project?:   false
- Does it use rollups?:   
- Is it multi-chain?:  
- Does it use a side-chain?: false
- Is this fresh code or have they been audited: fresh
- Describe any specific areas you would like addressed.: Please try to break the rebalancing logic (or suggest better implementations) + the drip mechanism of wxETH.
```
