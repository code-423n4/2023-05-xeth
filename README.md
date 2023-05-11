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

------

# Repo setup

## ⭐️ Sponsor: Add code to this repo

- [ ] Create a PR to this repo with the below changes:
- [ ] Provide a self-contained repository with working commands that will build (at least) all in-scope contracts, and commands that will run tests producing gas reports for the relevant contracts.
- [ ] Make sure your code is thoroughly commented using the [NatSpec format](https://docs.soliditylang.org/en/v0.5.10/natspec-format.html#natspec-format).
- [ ] Please have final versions of contracts and documentation added/updated in this repo **no less than 24 hours prior to contest start time.**
- [ ] Be prepared for a 🚨code freeze🚨 for the duration of the contest — important because it establishes a level playing field. We want to ensure everyone's looking at the same code, no matter when they look during the contest. (Note: this includes your own repo, since a PR can leak alpha to our wardens!)


---

## ⭐️ Sponsor: Edit this README

Under "SPONSORS ADD INFO HERE" heading below, include the following:

- [ ] Modify the bottom of this `README.md` file to describe how your code is supposed to work with links to any relevent documentation and any other criteria/details that the C4 Wardens should keep in mind when reviewing. ([Here's a well-constructed example.](https://github.com/code-423n4/2022-08-foundation#readme))
  - [ ] When linking, please provide all links as full absolute links versus relative links
  - [ ] All information should be provided in markdown format (HTML does not render on Code4rena.com)
- [ ] Under the "Scope" heading, provide the name of each contract and:
  - [ ] source lines of code (excluding blank lines and comments) in each
  - [ ] external contracts called in each
  - [ ] libraries used in each
- [ ] Describe any novel or unique curve logic or mathematical models implemented in the contracts
- [ ] Does the token conform to the ERC-20 standard? In what specific ways does it differ?
- [ ] Describe anything else that adds any special logic that makes your approach unique
- [ ] Identify any areas of specific concern in reviewing the code
- [ ] Optional / nice to have: pre-record a high-level overview of your protocol (not just specific smart contract functions). This saves wardens a lot of time wading through documentation.
- [ ] See also: [this checklist in Notion](https://code4rena.notion.site/Key-info-for-Code4rena-sponsors-f60764c4c4574bbf8e7a6dbd72cc49b4#0cafa01e6201462e9f78677a39e09746)
- [ ] Delete this checklist and all text above the line below when you're ready.

---
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
