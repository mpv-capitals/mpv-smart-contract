require('dotenv').config()
const contract = require('truffle-contract')
const Web3 = require('web3')
const fs = require('fs')
const glob = require('glob')
const HDWalletProvider = require('truffle-hdwallet-provider')

const zosJson = require('../zos.json')

let provider = new Web3.providers.HttpProvider('http://localhost:8545')
let network = process.argv[2]
let newOwnerAddress = process.argv[3]

if (network && network != 'development') {
  const url = `https://${network}.infura.io/v3/a6b85a49167f411b8c58834a16acf5ed`
  let key = process.env.PRIVATE_KEY
  if (process.env.MNEMONIC) {
    key = process.env.MNEMONIC
  }

  provider = new HDWalletProvider(key, url)
}

const gasPrice = 20000000000 // 20gwei

const web3 = new Web3(provider)

function getZosFile() {
  return JSON.parse(fs.readFileSync(`zos.${network}.json`))
}

async function setMainProxyAdmin() {
  const senderAddress = '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  const zosFile = getZosFile()
  const proxyAdminJson = require('./zos_abi/ProxyAdmin.json')
  const ProxyAdmin = contract(proxyAdminJson)
  ProxyAdmin.setProvider(provider);
  const proxyAdminContractAddress = zosFile.proxyAdmin.address
  const instance = await ProxyAdmin.at(proxyAdminContractAddress)

  console.log('current owner', await instance.owner.call())

  console.log('setting owner', newOwnerAddress)
  await instance.transferOwnership.sendTransaction(newOwnerAddress, {
    from: senderAddress,
    gas: 5712383,
    gasPrice
  })
  console.log('owner set')
}

async function main() {
  await setMainProxyAdmin()
  process.exit(0)
}

main()

