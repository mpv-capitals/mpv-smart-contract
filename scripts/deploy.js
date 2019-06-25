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

async function initializeContracts () {
  let senderAddress = privateKeyToAddress(privateKey)
  let redemptionFeeReceiverWallet = senderAddress
  let mintingReceiverWallet = senderAddress

  try {
    for (let key in zosJson.contracts) {
      const { stdout, stderr } = await exec(`npx zos create ${key} --network=development`)
      console.log(key)
      console.log('stdout:', stdout)
      console.log('stderr:', stderr)
    }

    let instance = await getInstance('SuperProtectorMultiSigWallet')
    await instance.initialize([senderAddress], 1, {
      from: senderAddress
    })

    instance = await getInstance('BasicProtectorMultiSigWallet')
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
      getProxyAddress('OperationAdminMultiSigWallet'),
      getProxyAddress('BasicProtectorMultiSigWallet'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('MPVToken')
    await instance.initialize(
      'Master Property Value',
      'MPV',
      18,
      getProxyAddress('Whitelist'),
      getProxyAddress('MasterPropertyValue'),
      getProxyAddress('MintingAdminRole'),
      getProxyAddress('RedemptionAdminRole'),
      getProxyAddress('SuperProtectorMultiSigWallet'),
      {
      from: senderAddress
    })

    instance = await getInstance('Assets')
    await instance.initialize(
      1000,
      redemptionFeeReceiverWallet,
      getProxyAddress('MintingAdminRole'),
      getProxyAddress('RedemptionAdminRole'),
      getProxyAddress('RedemptionAdminMultiSigWallet'),
      getProxyAddress('BasicProtectorMultiSigWallet'),
      getProxyAddress('MPVToken'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('SuperProtectorRole')
    await instance.initialize(
      getProxyAddress('SuperProtectorMultiSigWallet'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('BasicProtectorRole')
    await instance.initialize(
      getProxyAddress('BasicProtectorMultiSigWallet'),
      getProxyAddress('MintingAdminRole'),
      {
      from: senderAddress
    })

    instance = await getInstance('MintingAdminRole')
    await instance.initialize(
      getProxyAddress('MintingAdminMultiSigWallet'),
      getProxyAddress('Assets'),
      getProxyAddress('MPVToken'),
      getProxyAddress('SuperProtectorRole'),
      getProxyAddress('BasicProtectorRole'),
      mintingReceiverWallet,
      getProxyAddress('MasterPropertyValue'),
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
      getProxyAddress('RedemptionAdminMultiSigWallet'),
      getProxyAddress('BasicProtectorMultiSigWallet'),
      getProxyAddress('Assets'),
      getProxyAddress('MPVToken'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('MasterPropertyValue')
    await instance.initialize(
      getProxyAddress('MPVToken'),
      getProxyAddress('Assets'),
      getProxyAddress('Whitelist'),
      {
      from: senderAddress
    })
  } catch(err) {
    console.error(err)
    console.trace(err)
  }
}

async function setAdmins() {
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
    //const admin = await superProtectorMultiSig.admin.call({from: senderAddress})
    //console.log('admin', admin)
    //const w = await assets.basicProtectorMultiSig.call()
    //console.log(w)
    console.log('assets.updateMintingAdminRole')
    await assets.updateMintingAdminRole(mintingAdminRole.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('assets.updateRedemptionAdminRole')
    await assets.updateRedemptionAdminRole(redemptionAdminRole.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mpvToken.updateAssets')
    await mpvToken.updateAssets(assets.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mpvToken.updateSuperProtectorMultiSig')
    await mpvToken.updateSuperProtectorMultiSig(superProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mpvToken.updateMintingAdmin')
    await mpvToken.updateMintingAdmin(mintingAdminRole.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mpvToken.updateRedemptionAdmin')
    await mpvToken.updateRedemptionAdmin(redemptionAdminRole.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('superProtectorMultiSig.updateAdmin')
    await superProtectorMultiSig.updateAdmin(superProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('basicProtectorMultiSig.updateAdmin')
    await basicProtectorMultiSig.updateAdmin(superProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('operationAdminMultiSig.updateAdmin')
    await operationAdminMultiSig.updateAdmin(basicProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mintingAdminMultiSig.updateTransactor')
    await mintingAdminMultiSig.updateTransactor(mintingAdminRole.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mintingAdminMultiSig.updateTransactor')
    await mintingAdminMultiSig.updateAdmin(basicProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('redemptionAdminMultiSig.updateTransactor')
    await redemptionAdminMultiSig.updateTransactor(assets.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('redemptionAdminMultiSig.updateAdmin')
    await redemptionAdminMultiSig.updateAdmin(basicProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('mpv.updatePausableAdmin')
    await mpv.updatePausableAdmin(superProtectorMultiSig.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('whitelist.addWhitelisted')
    await whitelist.addWhitelisted(senderAddress, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })

    console.log('whitelist.addWhitelisted')
    await whitelist.addWhitelisted(assets.address, {
      from: senderAddress,
      gas: 5712383,
      gasPrice
    })
    console.log('done setting admins')
  } catch(err) {
    console.error(err)
    console.trace(err)
  }
}

async function main() {
  // commented out because it's done in deploy.sh
  //await initializeContracts()

  await setAdmins()
  process.exit(0)
}

main()

