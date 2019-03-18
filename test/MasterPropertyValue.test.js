const { shouldFail } = require('openzeppelin-test-helpers')

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const Assets = artifacts.require('Assets')
const SuperOwnerMultiSigWallet = artifacts.require('SuperOwnerMultiSigWallet')
const BasicOwnerMultiSigWallet = artifacts.require('BasicOwnerMultiSigWallet')

contract('MPV', accounts => {
  let mpv = null
  let assets = null
  let superOwnerMultiSig = null
  let basicOwnerMultiSig = null

  it('should deploy contract', async () => {
    assets = await Assets.new()
    superOwnerMultiSig = await SuperOwnerMultiSigWallet.new([accounts[0]], 1)
    basicOwnerMultiSig = await BasicOwnerMultiSigWallet.new([accounts[0]], 1)

    await MPV.link({
      Assets: assets.address,
    })

    mpv = await MPV.new()
    mpv.initialize(
      superOwnerMultiSig.address,
      basicOwnerMultiSig.address
    )

    await superOwnerMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })

    await basicOwnerMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })
  })

  it('add 2nd super owner', async () => {
    const newOwner = accounts[2]
    const txId = await mpv.addSuperOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addSuperOwner(newOwner, {
      from: accounts[0],
    })

    txId.toString().should.equal('0')

    let confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
    confirmationCount.length.should.equal(0)

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
    confirmationCount.length.should.equal(1)

    const required = await superOwnerMultiSig.required.call()
    required.toString().should.equal('1')
  })

  it('verify account is 2nd super owner', async () => {
    const isConfirmed = await superOwnerMultiSig.isConfirmed.call('0')
    isConfirmed.should.equal(true)

    const owner = accounts[2]
    const owners = await superOwnerMultiSig.getOwners.call()
    owners.length.should.equal(2)
    const res = await mpv.isSuperOwner.call(owner)
    res.should.equal(true)
  })

  it('add 3rd super owner', async () => {
    const newOwner = accounts[3]
    const txId = await mpv.addSuperOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addSuperOwner(newOwner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })
  })

  it('add 4th super owner', async () => {
    const newOwner = accounts[4]
    const txId = await mpv.addSuperOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addSuperOwner(newOwner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })
  })

  it('add 5th super owner', async () => {
    const newOwner = accounts[5]
    const txId = await mpv.addSuperOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addSuperOwner(newOwner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })
  })

  it('add 6th super owner but require 40% of confirmations', async () => {
    let count = await mpv.getSuperOwners.call()
    count.length.should.equal(5)

    const threshold = await mpv.superOwnerActionsThreshold.call()
    threshold.toString().should.equal('40')

    let required = await superOwnerMultiSig.required.call()
    required.toString().should.equal('2')

    const newOwner = accounts[6]
    const txId = await mpv.addSuperOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addSuperOwner(newOwner, {
      from: accounts[0],
    })

    const confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
    confirmationCount.length.should.equal(0)

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    let isOwner = await mpv.isSuperOwner.call(newOwner)
    isOwner.should.equal(false)

    const notAnOwner = accounts[1]
    await shouldFail(superOwnerMultiSig.confirmTransaction(txId, {
      from: notAnOwner,
    }))

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[2],
    })

    required = await superOwnerMultiSig.required.call()
    required.toString().should.equal('2')

    isOwner = await mpv.isSuperOwner.call(newOwner)
    isOwner.should.equal(true)

    count = await mpv.getSuperOwners.call()
    count.length.should.equal(6)
  })

  it('remove 5th super owner', async () => {
    const owner = accounts[5]

    let isOwner = await mpv.isSuperOwner.call(owner)
    isOwner.should.equal(true)

    const txId = await mpv.removeSuperOwner.call(owner, {
      from: accounts[0],
    })
    await mpv.removeSuperOwner(owner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[2],
    })

    isOwner = await mpv.isSuperOwner.call(owner)
    isOwner.should.equal(false)

    const count = await mpv.getSuperOwners.call()
    count.length.should.equal(5)

    const required = await superOwnerMultiSig.required.call()
    required.toString().should.equal('2')
  })

  it('remove 6th super owner', async () => {
    const owner = accounts[6]

    let isOwner = await mpv.isSuperOwner.call(owner)
    isOwner.should.equal(true)

    const txId = await mpv.removeSuperOwner.call(owner, {
      from: accounts[0],
    })
    await mpv.removeSuperOwner(owner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[2],
    })

    isOwner = await mpv.isSuperOwner.call(owner)
    isOwner.should.equal(false)

    const count = await mpv.getSuperOwners.call()
    count.length.should.equal(4)

    const required = await superOwnerMultiSig.required.call()
    required.toString().should.equal('1')
  })

  it('add 2nd basic owner', async () => {
    const newOwner = accounts[11]

    let isOwner = await mpv.isBasicOwner.call(newOwner)
    isOwner.should.equal(false)

    const txId = await mpv.addBasicOwner.call(newOwner, {
      from: accounts[0],
    })
    await mpv.addBasicOwner(newOwner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    isOwner = await mpv.isBasicOwner.call(newOwner)
    isOwner.should.equal(true)
  })

  it('remove 2nd basic owner', async () => {
    const owner = accounts[11]

    let isOwner = await mpv.isBasicOwner.call(owner)
    isOwner.should.equal(true)

    const txId = await mpv.removeBasicOwner.call(owner, {
      from: accounts[0],
    })
    await mpv.removeBasicOwner(owner, {
      from: accounts[0],
    })

    await superOwnerMultiSig.confirmTransaction(txId, {
      from: accounts[0],
    })

    isOwner = await mpv.isBasicOwner.call(owner)
    isOwner.should.equal(false)
  })

  it('add asset', async () => {
    const asset = {
      id: 1,
      valuation: 50,
      fingerprint: '0xabcd',
      tokens: 100,
    }

    await mpv.addAsset(asset)
  })

  it('get asset', async () => {
    const asset = await mpv.getAsset.call(1)
    asset.tokens.should.equal('100')
  })

  it('add multiple assets', async () => {
    const assets = [{
      id: 2,
      valuation: 50,
      fingerprint: '0xabcd',
      tokens: 100,
    }, {
      id: 3,
      valuation: 70,
      fingerprint: '0x1234',
      tokens: 100,
    }]

    await mpv.addAssets(assets)
  })
})
