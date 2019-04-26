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
  const files = glob.sync('zos.dev-*.json')
  const zosDevJson = JSON.parse(fs.readFileSync(files[0]))
  console.log(name)
  return zosDevJson.contracts[name].address
}

function getJson (name) {
  return require(`../build/contracts/${name}.json`)
}

async function initializeContracts () {
  let senderAddress = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  let redemptionFeeReceiverWallet = senderAddress
  let mintingReceiverWallet = senderAddress

  try {
    for (let key in zosJson.contracts) {
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
      getProxyAddress('OperationAdminMultiSigWallet'),
      getProxyAddress('BasicOwnerMultiSigWallet'),
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
      getProxyAddress('SuperOwnerMultiSigWallet'),
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
      getProxyAddress('BasicOwnerMultiSigWallet'),
      getProxyAddress('MPVToken'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('SuperOwnerRole')
    await instance.initialize(
      getProxyAddress('SuperOwnerMultiSigWallet'),
      getProxyAddress('MasterPropertyValue'),
      {
      from: senderAddress
    })

    instance = await getInstance('BasicOwnerRole')
    await instance.initialize(
      getProxyAddress('BasicOwnerMultiSigWallet'),
      getProxyAddress('MintingAdminRole'),
      {
      from: senderAddress
    })

    instance = await getInstance('MintingAdminRole')
    await instance.initialize(
      getProxyAddress('MintingAdminMultiSigWallet'),
      getProxyAddress('Assets'),
      getProxyAddress('MPVToken'),
      getProxyAddress('SuperOwnerRole'),
      getProxyAddress('BasicOwnerRole'),
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
      getProxyAddress('BasicOwnerMultiSigWallet'),
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
  let senderAddress = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  let superOwnerMultiSig = await getInstance('SuperOwnerMultiSigWallet', true)
  let basicOwnerMultiSig = await getInstance('BasicOwnerMultiSigWallet', true)
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
    //const admin = await superOwnerMultiSig.admin.call({from: senderAddress})
    //console.log('admin', admin)
    //const w = await assets.basicOwnerMultiSig.call()
    //console.log(w)
    console.log(0)
    await assets.updateMintingAdminRole(mintingAdminRole.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(0.01)
    await assets.updateRedemptionAdminRole(redemptionAdminRole.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(0.1)
    await mpvToken.updateMintingAdmin(mintingAdminRole.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(0.2)
    await mpvToken.updateRedemptionAdmin(redemptionAdminRole.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(0.3)
    await superOwnerMultiSig.updateAdmin(superOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(1)
    await basicOwnerMultiSig.updateAdmin(superOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(2)
    await operationAdminMultiSig.updateAdmin(basicOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(3)
    await mintingAdminMultiSig.updateTransactor(mintingAdminRole.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(4)
    await mintingAdminMultiSig.updateAdmin(basicOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(5)
    await redemptionAdminMultiSig.updateTransactor(assets.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(6)
    await redemptionAdminMultiSig.updateAdmin(basicOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(7)
    await mpv.updatePausableAdmin(superOwnerMultiSig.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(8)
    await whitelist.addWhitelisted(senderAddress, {
      from: senderAddress,
      gas: 7712383,
    })
    await whitelist.addWhitelisted(assets.address, {
      from: senderAddress,
      gas: 7712383,
    })
    console.log(10)
  } catch(err) {
    console.error(err)
    console.trace(err)
  }
}

async function main() {
  //await initializeContracts()
  await setAdmins()
  process.exit(0)
}

main()

