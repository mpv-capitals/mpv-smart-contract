# Master Property Value contracts

> Ethereum smart contracts for Master Property Value assets

[![License](http://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/levelkdev/master-property-value-token/master/LICENSE)
[![CircleCI](https://circleci.com/gh/levelkdev/master-property-value-token.svg?style=svg)](https://circleci.com/gh/levelkdev/master-property-value-token)
[![dependencies Status](https://david-dm.org/levelkdev/master-property-value-token/status.svg)](https://david-dm.org/levelkdev/master-property-value-token)

## Development

Instructions for getting started:

### Install

Install dependencies:

```bash
make install
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

  - First create a `.env` file with either a `MNEMONIC` or `PRIVATE_KEY` variable to export.

    ```bash
    MNEMONIC='myth like bonus scare over problem client lizard pioneer submit female collect'
    # or
    PRIVATEK_KEY=0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d
    ```
  - Run deploy make rule passing in the desired network to deploy to:

    ```bash
    make deploy network=mainnet
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

## License

[MIT](LICENSE)
