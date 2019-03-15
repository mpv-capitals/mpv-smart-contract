const {
  Contracts,
  SimpleProject,
  ZWeb3,
  encodeCall
} = require('zos-lib')
const { TestHelper } = require('zos')
const moment = require('moment')

ZWeb3.initialize(web3.currentProvider)

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const Assets = artifacts.require('Assets')
const Polls = artifacts.require('Polls')
const MultiSigWallet = artifacts.require('MultiSigWallet')

contract('MPV', accounts => {
  let instance = null

  it('should deploy contract', async () => {
    const polls = await Polls.new()
    const assets = await Assets.new()
    const owners = await MultiSigWallet.new([accounts[0]], 1)
    await MPV.link({
      Polls: polls.address,
      Assets: assets.address
    })

    instance = await MPV.new()
    instance.initialize(owners.address)

    const data = encodeCall(
      'addOwner',
      ['address'],
      [instance.address]
    )

    await owners.submitTransaction(owners.address, 0, data, {
      from: accounts[0]
    })

    const isOwner = await owners.isOwner.call(instance.address)
    isOwner.should.equal(true)
  })

  it('add owner', async () => {
    const newOwner = '0x4ccA5F2f01746B1c13ca7a3Dab0462d225795D3A'
    const walletTxId = await instance.addOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addOwner(newOwner, {
      from: accounts[0]
    })

    walletTxId.toString().should.equal('1')
  })

  it.skip('execute', async () => {
    await instance.execute(1)
  })

  it('is owner', async () => {
    const owner = '0x4ccA5F2f01746B1c13ca7a3Dab0462d225795D3A'
    const res = await instance.isOwner.call(owner)
    res.should.equal(true)
  })

  it('add asset', async () => {
    const asset = {
      id: 1,
      valuation: 50,
      fingerprint: '0xabcd',
      tokens: 100
    }

    await instance.addAsset(asset)
  })

  it('get asset', async () => {
    const asset = await instance.getAsset.call(1)
    asset.tokens.should.equal('100')
  })

  it('add assets', async () => {
    const assets = [{
      id: 2,
      valuation: 50,
      fingerprint: '0xabcd',
      tokens: 100
    }, {
      id: 3,
      valuation: 70,
      fingerprint: '0x1234',
      tokens: 100
    }]

    await instance.addAssets(assets)
  })
})
