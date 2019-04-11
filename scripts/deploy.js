const util = require('util')
const Web3 = require('web3')
const exec = util.promisify(require('child_process').exec)
const { encodeCall } = require('zos-lib')
const contract = require('truffle-contract')
const fs = require('fs')
const glob = require('glob')
const zosJson = require('../zos.json')

const json = {
  SuperOwnerMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  BasicOwnerMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  MintingAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  OperationAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  RedemptionAdminMultiSigWallet: getJson('AdministeredMultiSigWallet'),
  Whitelist: getJson('Whitelist'),
  MPVToken: getJson('MPVToken'),
  Assets: getJson('Assets'),
  SuperOwnerRole: getJson('SuperOwnerRole'),
  BasicOwnerRole: getJson('BasicOwnerRole'),
  MintingAdminRole: getJson('MintingAdminRole'),
  MasterPropertyValue: getJson('MasterPropertyValue'),
  RedemptionAdminRole: getJson('RedemptionAdminRole'),
  Pausable: getJson('Pausable')
}

const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

function getProxyAddress(name) {
  const files = glob.sync('zos.dev-*.json')
  const zosDevJson = JSON.parse(fs.readFileSync(files[0]))
  const zosProxyAddress = zosDevJson.proxies[`master-property-value/${name}`][0].address
  return zosProxyAddress
}

async function getInstance(name) {
  let MyContract = contract(json[name])
  MyContract.setProvider(provider)
  let instance = await MyContract.at(getAddress(name))
  return instance
}

function getAddress(name) {
  const files = glob.sync('zos.dev-*.json')
  const zosDevJson = JSON.parse(fs.readFileSync(files[0]))
  console.log(name)
  return zosDevJson.contracts[name].address
}

function getJson (name) {
  return require(`../build/contracts/${name}.json`)
}

async function main () {
  var senderAddress = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  var redemptionFeeReceiverWallet = senderAddress
  var mintingReceiverWallet = senderAddress

  for (var key in zosJson.contracts) {
    const { stdout, stderr } = await exec(`npx zos create ${key} --network=development`)
    console.log(key)
    console.log('stdout:', stdout)
    console.log('stderr:', stderr)
  }

  let instance = await getInstance('SuperOwnerMultiSigWallet')
  await instance.initialize([senderAddress], 1, {
    from: senderAddress
  })

  instance = await getInstance('BasicOwnerMultiSigWallet')
  await instance.initialize([senderAddress], 1, {
    from: senderAddress
  })

  instance = await getInstance('MintingAdminMultiSigWallet')
  await instance.initialize([senderAddress], 1, {
    from: senderAddress
  })

  instance = await getInstance('OperationAdminMultiSigWallet')
  await instance.initialize([senderAddress], 1, {
    from: senderAddress
  })

  instance = await getInstance('RedemptionAdminMultiSigWallet')
  await instance.initialize([senderAddress], 1, {
    from: senderAddress
  })

  instance = await getInstance('Whitelist')
  await instance.initialize(
    getAddress('OperationAdminMultiSigWallet'),
    getAddress('BasicOwnerMultiSigWallet'),
    getAddress('MasterPropertyValue'),
    {
    from: senderAddress
  })

  instance = await getInstance('MPVToken')
  await instance.initialize(
    'Master Property Value',
    'MPV',
    18,
    getAddress('Whitelist'),
    getAddress('MasterPropertyValue'),
    getAddress('MintingAdminRole'),
    getAddress('RedemptionAdminRole'),
    getAddress('SuperOwnerMultiSigWallet'),
    {
    from: senderAddress
  })

  instance = await getInstance('Assets')
  await instance.initialize(
    1000,
    redemptionFeeReceiverWallet,
    getAddress('MintingAdminRole'),
    getAddress('RedemptionAdminRole'),
    getAddress('RedemptionAdminMultiSigWallet'),
    getAddress('BasicOwnerMultiSigWallet'),
    getAddress('MPVToken'),
    getAddress('MasterPropertyValue'),
    {
    from: senderAddress
  })

  instance = await getInstance('SuperOwnerRole')
  await instance.initialize(
    getAddress('SuperOwnerMultiSigWallet'),
    getAddress('MasterPropertyValue'),
    {
    from: senderAddress
  })

  instance = await getInstance('BasicOwnerRole')
  await instance.initialize(
    getAddress('BasicOwnerMultiSigWallet'),
    getAddress('MintingAdminRole'),
    {
    from: senderAddress
  })

  instance = await getInstance('MintingAdminRole')
  await instance.initialize(
    getAddress('MintingAdminMultiSigWallet'),
    getAddress('Assets'),
    getAddress('MPVToken'),
    getAddress('SuperOwnerRole'),
    getAddress('BasicOwnerRole'),
    mintingReceiverWallet,
    getAddress('MasterPropertyValue'),
    {
    from: senderAddress
  })

  instance = await getInstance('Pausable')
  await instance.initialize(
    {
    from: senderAddress
  })

  instance = await getInstance('RedemptionAdminRole')
  await instance.initialize(
    getAddress('RedemptionAdminMultiSigWallet'),
    getAddress('BasicOwnerMultiSigWallet'),
    getAddress('Assets'),
    getAddress('MPVToken'),
    getAddress('MasterPropertyValue'),
    {
    from: senderAddress
  })

  instance = await getInstance('MasterPropertyValue')
  await instance.initialize(
    getAddress('MPVToken'),
    getAddress('Assets'),
    getAddress('Whitelist'),
    {
    from: senderAddress
  })

  process.exit(0)
}

main()
