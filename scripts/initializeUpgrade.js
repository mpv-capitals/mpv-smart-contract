require('dotenv').config()
const util = require('util')
const Web3 = require('web3')
const exec = util.promisify(require('child_process').exec)
const { encodeCall } = require('zos-lib')
const contract = require('truffle-contract')
const fs = require('fs')
const glob = require('glob')
const HDWalletProvider = require('truffle-hdwallet-provider')
const PrivateKeyProvider = require('truffle-privatekey-provider')
const privateKeyToAddress = require('ethereum-private-key-to-address')

const zosJson = require('../zos.json')

const json = {
  SuperProtectorMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  BasicProtectorMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  MintingAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  OperationAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  RedemptionAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  Whitelist: getJson('Whitelist'),
  MPVToken: getJson('MPVToken'),
  Assets: getJson('Assets'),
  SuperProtectorRole: getJson('SuperProtectorRole'),
  BasicProtectorRole: getJson('BasicProtectorRole'),
  MintingAdminRole: getJson('MintingAdminRole'),
  MasterPropertyValue: getJson('MasterPropertyValue'),
  RedemptionAdminRole: getJson('RedemptionAdminRole'),
  Pausable: getJson('Pausable')
}

let provider = new Web3.providers.HttpProvider('http://localhost:8545')

let network = process.argv[2]
let zosFilePath = process.argv[3]
let privateKey = ''

if (network && network != 'development') {
  const url = `https://${network}.infura.io/v3/a6b85a49167f411b8c58834a16acf5ed`
  privateKey = (process.env.PRIVATE_KEY || '').replace(/^0x/, '')
  if (process.env.MNEMONIC) {
    privateKey = process.env.MNEMONIC
  }

  provider = new HDWalletProvider(privateKey, url)
}

const gasPrice = process.env.GAS_PRICE || 5000000000 // 5 gwei

const web3 = new Web3(provider)

function getZosFile() {
  let zosFile = null
  if (zosFilePath) {
    zosFile = JSON.parse(fs.readFileSync(zosFilePath))
  } else {
    const files = glob.sync('zos.*.json')
    zosFile = JSON.parse(fs.readFileSync(files[0]))
  }
  return zosFile
}

function getProxyAddress(name) {
  const zosFile = getZosFile()

  const zosProxyAddress = zosFile.proxies[`master-property-value/${name}`][0].address
  return zosProxyAddress
}

async function getInstance(name, proxy) {
  let MyContract = contract(json[name])
  MyContract.setProvider(provider)
  let address = getAddress(name)
  if (proxy) {
    address = getProxyAddress(name)
  }
  let instance = await MyContract.at(address)
  console.log(`getInstance(${name})`)
  return instance
}

function getAddress(name) {
  const files = glob.sync('zos.*.json')
  const zosDevJson = JSON.parse(fs.readFileSync(files[0]))
  console.log(name)
  return zosDevJson.contracts[name].address
}

function getJson (name) {
  return require(`../build/contracts/${name}.json`)
}

async function setMultisig() {
  let senderAddress = privateKeyToAddress(privateKey)

  let superProtectorMultiSig = await getInstance('SuperProtectorMultiSigWallet', true)
  let basicProtectorMultiSig = await getInstance('BasicProtectorMultiSigWallet', true)
  let operationAdminMultiSig = await getInstance('OperationAdminMultiSigWallet', true)
  let mintingAdminMultiSig = await getInstance('MintingAdminMultiSigWallet', true)
  let mintingAdminRole = await getInstance('MintingAdminRole', true)
  let assets = await getInstance('Assets', true)
  let redemptionAdminRole = await getInstance('RedemptionAdminRole', true)
  let redemptionAdminMultiSig = await getInstance('RedemptionAdminMultiSigWallet', true)
  let mpv  = await getInstance('MasterPropertyValue', true)
  let mpvToken  = await getInstance('MPVToken', true)
  let whitelist = await getInstance('Whitelist', true)

  try {
    console.log('mpvToken.initializeBasicProtectorMultiSig')
    await mpvToken.initializeBasicProtectorMultiSig(basicProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('done')
  } catch(err) {
    console.error(err)
    console.trace(err)
  }
}

async function main() {
  await setMultisig()
  process.exit(0)
}

main()

