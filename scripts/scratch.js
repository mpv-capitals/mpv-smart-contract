// scratch pad

const Web3 = require('web3')
const { encodeCall } = require('zos-lib')
const contract = require("truffle-contract");

const contractJson = require('../build/contracts/AdministeredMultiSigWallet.json')
const abi = contractJson.abi
const contractAddress = '0xba1B19248020B0dfcDc9C53eAE31722B478334aE'

const provider = new Web3.providers.HttpProvider('http://localhost:8545')
const web3 = new Web3(provider)

//let instance = new web3.eth.Contract(abi)

async function main() {
  var MyContract = contract(contractJson)
  MyContract.setProvider(provider);
  var instance = await MyContract.at(contractAddress)
  /*
  var instance = await MyContract.new({
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  })
  */
  console.log(instance.address)

  /*
  const admin = await instance.methods.admin({
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  })
  console.log(admin)
  */

  /*
  await instance.initialize(['0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'], 1, {
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
    gas: 7712383,
  })
  */
  /*
  await instance.updateAdmin(instance.address, {
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  })
  */

  let data = encodeCall(
    'addOwner',
    ['address'],
    ['0xffcf8fdee72ac11b5c542428b35eef5769c409f0']
  )

  console.log('data', data.toString())

  const hasOwner = await instance.hasOwner.call('0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1', {
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  })
  console.log(hasOwner)

  let result = await instance.submitTransaction.call(contractAddress, 0, data, {
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1'
  })
  console.log(result)

  result = await instance.submitTransaction(contractAddress, 0, data, {
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
    gas: 7712383,
  })
  console.log(result)

  /*
  const count = await instance.methods.transactionCount().call({
    from: '0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1',
  })
  console.log(count)
  */

  process.exit(0)
}

main()
