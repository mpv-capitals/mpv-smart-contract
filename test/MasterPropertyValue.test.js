const {
  Contracts,
  SimpleProject,
  ZWeb3,
  encodeCall
} = require('zos-lib')
const { TestHelper } = require('zos')
const { shouldFail } = require('openzeppelin-test-helpers')
const moment = require('moment')

ZWeb3.initialize(web3.currentProvider)

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const Assets = artifacts.require('Assets')
const Polls = artifacts.require('Polls')
const MultiSigWallet = artifacts.require('MultiSigWallet')
const SuperOwnerMultiSigWallet = artifacts.require('SuperOwnerMultiSigWallet')

contract('MPV', accounts => {
  let instance = null
  let polls = null
  let assets = null
  let superOwners = null

  it('should deploy contract', async () => {
    polls = await Polls.new()
    assets = await Assets.new()
    superOwners = await SuperOwnerMultiSigWallet.new([accounts[0]], 1)

    await MPV.link({
      Polls: polls.address,
      Assets: assets.address
    })

    instance = await MPV.new()
    instance.initialize(superOwners.address)

    await superOwners.setMPV(instance.address, {
      from: accounts[0]
    })

    /*
    const data = encodeCall(
      'addOwner',
      ['address'],
      [instance.address]
    )

    await superOwners.submitTransaction(superOwners.address, 0, data, {
      from: accounts[0]
    })

    const isOwner = await superOwners.isOwner.call(instance.address)
    isOwner.should.equal(true)
    */
  })

  it('add 2nd super owner', async () => {
    const newOwner = accounts[2]
    const txId = await instance.addSuperOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addSuperOwner(newOwner, {
      from: accounts[0]
    })

    txId.toString().should.equal('0')

    let confirmationCount = await superOwners.getConfirmations.call(txId)
    confirmationCount.length.should.equal(0)

    await superOwners.confirmTransaction(txId, {
      from: accounts[0]
    })

    confirmationCount = await superOwners.getConfirmations.call(txId)
    confirmationCount.length.should.equal(1)

    const req = await superOwners.required.call()
    req.toString().should.equal('1')
  })

  it('verify account is 2nd super owner', async () => {
    const isConfirmed = await superOwners.isConfirmed.call('0')

    const owner = accounts[2]
    const owners = await superOwners.getOwners.call()
    owners.length.should.equal(2)
    const res = await instance.isSuperOwner.call(owner)
    res.should.equal(true)
  })

  it('add 3rd super owner', async () => {
    const newOwner = accounts[3]
    const txId = await instance.addSuperOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addSuperOwner(newOwner, {
      from: accounts[0]
    })

    await superOwners.confirmTransaction(txId, {
      from: accounts[0]
    })
  })

  it('add 4th super owner', async () => {
    const newOwner = accounts[4]
    const txId = await instance.addSuperOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addSuperOwner(newOwner, {
      from: accounts[0]
    })

    await superOwners.confirmTransaction(txId, {
      from: accounts[0]
    })
  })

  it('add 5th super owner', async () => {
    const newOwner = accounts[5]
    const txId = await instance.addSuperOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addSuperOwner(newOwner, {
      from: accounts[0]
    })

    await superOwners.confirmTransaction(txId, {
      from: accounts[0]
    })
  })

  it('add 6th super owner but require 40% of confirmations', async () => {
    const count = await instance.getSuperOwners.call()
    count.length.should.equal(5)

    const threshold = await instance.superOwnerActionsThreshold.call()
    threshold.toString().should.equal('40')

    let req = await superOwners.required.call()
    req.toString().should.equal('2')

    const newOwner = accounts[6]
    const txId = await instance.addSuperOwner.call(newOwner, {
      from: accounts[0]
    })
    await instance.addSuperOwner(newOwner, {
      from: accounts[0]
    })

    const confirmationCount = await superOwners.getConfirmations.call(txId)
    confirmationCount.length.should.equal(0)

    await superOwners.confirmTransaction(txId, {
      from: accounts[0]
    })

    let isOwner = await instance.isSuperOwner.call(newOwner)
    isOwner.should.equal(false)

    const notAnOwner = accounts[1]
    await shouldFail(superOwners.confirmTransaction(txId, {
      from: notAnOwner
    }))

    await superOwners.confirmTransaction(txId, {
      from: accounts[2]
    })

    req = await superOwners.required.call()
    req.toString().should.equal('2')

    isOwner = await instance.isSuperOwner.call(newOwner)
    isOwner.should.equal(true)
  })

  it.skip('execute', async () => {
    await instance.execute(1)
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
