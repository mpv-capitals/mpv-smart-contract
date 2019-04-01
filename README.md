# Master Property Value contracts

> Ethereum smart contracts for Master Property Value assets

[![License](http://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/levelkdev/master-property-value-token/master/LICENSE)
[![CircleCI](https://circleci.com/gh/levelkdev/master-property-value-token.svg?style=svg)](https://circleci.com/gh/levelkdev/master-property-value-token)
[![dependencies Status](https://david-dm.org/levelkdev/master-property-value-token/status.svg)](https://david-dm.org/levelkdev/master-property-value-token)

## Install

```bash
make install
```

## Ganache

```bash
make start
```

## Test

```bash
make test
```

## Lint

```bash
make lint
```

## Deploy

First create a `.env` file with either a `MNEMONIC` or `PRIVATE_KEY` variable to export.

```bash
make deploy network=mainnet
```

## Documentation

```bash
make docs && make docs/site/build
```


## License

[MIT](LICENSE)
