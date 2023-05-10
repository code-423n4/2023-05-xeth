# xETH

> LSD (Liquid Staking Derivative) Aggregator as a Service.

The smart contracts have been written using Forge which is a part of the Foundry Solidity Development Stack

## Getting Started

```
git submodule update --init --recursive  ## initialize submodule dependencies
npm install ## install development dependencies
forge build
forge test
```

### Tests

You can run tests by using the following command:

```
forge test
```

Please note that the tests for this codebase are _NON EXHAUSTIVE_. They do not cover every single case of the protocol, but do help in development and testing certain features / aspects of the code.

### Linting

Pre-configured `solhint` and `prettier-plugin-solidity`. Can be run by

```
npm run solhint
npm run prettier
```

### CI with Github Actions

Automatically run linting and tests on pull requests.

### Default Configuration

Including `.gitignore`, `.vscode`, `remappings.txt`
