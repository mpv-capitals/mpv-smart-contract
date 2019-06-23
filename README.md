# Master Property Value Contracts

> [Ethereum](https://www.ethereum.org/) smart contracts for [Master Property Value](https://mpv.world/)

[![License](http://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/levelkdev/master-property-value-token/master/LICENSE)
[![CircleCI](https://circleci.com/gh/levelkdev/master-property-value-token.svg?style=svg&circle-token=b94fe4a0faefdcfdbfef6b1516e77c262dd41a08)](https://circleci.com/gh/levelkdev/master-property-value-token)
[![dependencies Status](https://david-dm.org/levelkdev/master-property-value-token/status.svg)](https://david-dm.org/levelkdev/master-property-value-token)

## Development

Instructions for getting started:

### Install

Install dependencies:

```bash
make install
```

Install global commands:

```bash
npm i -g zos
npm i -g truffle
npm i -g ganache-cli
```

### Ganache

Start [ganache-cli](https://github.com/trufflesuite/ganache-cli):

```bash
make start
```

### Lint

Perform [standard](https://standardjs.com/) linting on tests files and [solhint](https://github.com/protofire/solhint) linting on solidity contracts:

```bash
make lint
```

## Test

Run all tests (requires ganache to be running):

```bash
make test
```

## Deploy

For deployment:

  - First create a `.env` file with either a `MNEMONIC` or `PRIVATE_KEY` variable to export, for example:

    ```bash
    MNEMONIC='myth like bonus scare over problem client lizard pioneer submit female collect'
    # or
    PRIVATE_KEY=0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d
    ```
  - Run deploy make rule passing in the desired network to deploy to:

    ```bash
    make deploy network=mainnet
    ```

  - Afterwards set the owner for the proxy admin contract:

    ```bash
    make set-admin network=mainnet admin=0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0
    ```

## Documentation

Compile solidity documentation:

```bash
make docs
```

Build [docusaurus](https://docusaurus.io/) website:

```bash
make docs/site/build
```

The output will be in `docs/build` which you can deploy.

You can also run docs website locally:

```bash
make docs/site/start
```

## FAQ

- Q: I'm getting the error `sh: 1: node: Permission denied` when installing NPM modules!

  - A: Set the following config:

    ```bash
    npm config set user 0
    npm config set unsafe-perm true
    ```

- Q: I'm getting the error `Cannot read property 'match' of undefined` when installing NPM modules!

  - A: Try deleting `package-lock.json`

    ```bash
    rm package-lock.json
    ```

- Q: I'm getting the error `Cannot read property 'match' of undefined` when installing NPM modules!

  - A: Try deleting `package-lock.json`

    ```bash
    rm package-lock.json
    ```

- Q: I'm getting the error `Error: not found: make` when installing NPM modules!

  - A: Install the build tools:

    ```bash
    sudo apt-get install build-essentials
    ```

- Q: I'm getting the error `Can't find Python executable "python", you can set the PYTHON env variable.` when installing NPM modules!

  - A: Install python (versions 2.7 and 3.6+):

    ```bash
    sudo apt-get install python2.7
    ln -s /usr/bin/python2.7 /usr/local/bin/python
    ```

## License

[MIT](LICENSE)
