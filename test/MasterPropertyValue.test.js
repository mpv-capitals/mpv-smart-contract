const { Contracts, SimpleProject, ZWeb3 } = require('zos-lib')
const { TestHelper } = require('zos')
const moment = require('moment')

ZWeb3.initialize(web3.currentProvider)

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const Assets = artifacts.require('Assets')
const Polls = artifacts.require('Polls')

contract('MPV', accounts => {
  let instance = null

  it('should deploy contract', async () => {
    const polls = await Polls.new()
    const assets = await Assets.new()
    await MPV.link({
      Polls: polls.address,
      Assets: assets.address
    })

    instance = await MPV.new()
    instance.initialize()
  })

  it('add owner', async () => {
    const newOwner = '0x4ccA5F2f01746B1c13ca7a3Dab0462d225795D3A'
    await instance.addOwner(newOwner)
  })

  it('execute', async () => {
    const owner = '0x4ccA5F2f01746B1c13ca7a3Dab0462d225795D3A'
    const key = web3.utils.keccak256(
      web3.eth.abi.encodeParameters(
        ['string', 'address'],
        ['addOwner', owner]
      )
    )

    await instance.execute(key)
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
