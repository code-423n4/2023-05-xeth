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
- Submit findings [using the C4 form](https://code4rena.com/contests/2023-05-xeth-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts May 12, 2023 20:00 UTC
- Ends May 15, 2023 20:00 UTC

## Automated Findings / Publicly Known Issues

Automated findings output for the contest can be found [here](add link to report) within 24 hours of contest opening.

_Note for C4 wardens: Anything included in the automated findings output is considered a publicly known issue and is ineligible for awards._

[ ⭐️ SPONSORS ADD INFO HERE ]

# Overview

> LSD (Liquid Staking Derivative) Aggregator as a Service.

# Scope

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [xeth/src/AMO2.sol](xeth/src/AMO2.sol) | 330 | AMO Contract for xETH | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and Curve |
| [xeth/src/CVXStaker.sol](xeth/src/CVXStaker.sol) | 142 | Staking xETH-stETH LP tokens to CVX, used by the AMO | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and Curve |
| [xeth/src/wxETH.sol](xeth/src/wxETH.sol) | 113 | wxETH is xETH staking to get rewards | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) and [`solmate/`](xeth/lib/solmate) |
| [xeth/src/xETH.sol](xeth/src/xETH.sol) | 51 | xETH is a mintable ERC20 token with pausing | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) |

## Setup Instructions

```bash
git submodule update --init --recursive  ## initialize submodule dependencies
npm install ## install development dependencies
forge build
forge test
```

### Tests

You can run tests by using the following command:

```bash
forge test
```

Please note that the tests for this codebase are _NON EXHAUSTIVE_. They do not cover every single case of the protocol, but do help in development and testing certain features / aspects of the code.
