const { shouldFail } = require('openzeppelin-test-helpers')
const { encodeCall } = require('zos-lib')
const moment = require('moment')
const { Actions, Roles, mine } = require('./helpers')

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const MPVToken = artifacts.require('MPVToken')
const Assets = artifacts.require('Assets')
const MPVState = artifacts.require('MPVState')
const SuperOwnerRole = artifacts.require('SuperOwnerRole')
const BasicOwnerRole = artifacts.require('BasicOwnerRole')
const OperationAdminRole = artifacts.require('OperationAdminRole')
const MintingAdminRole = artifacts.require('MintingAdminRole')
const RedemptionAdminRole = artifacts.require('RedemptionAdminRole')

const Whitelist = artifacts.require('Whitelist')
const AdministeredMultiSigWallet = artifacts.require('AdministeredMultiSigWallet')

let mpv = null
let mpvState = null
let mpvToken = null

let superOwnerRole = null
let basicOwnerRole = null
let operationAdminRole = null
let mintingAdminRole = null
let redemptionAdminRole = null

let assets = null
let superOwnerMultiSig = null
let basicOwnerMultiSig = null
let operationAdminMultiSig = null
let mintingAdminMultiSig = null
let redemptionAdminMultiSig = null
let whitelist = null

let mintingReceiverWallet = null

async function initContracts (accounts) {
  assets = await Assets.new()
  await assets.initialize(1000)
  mpvState = await MPVState.new()
  basicOwnerRole = await BasicOwnerRole.new()
  operationAdminRole = await OperationAdminRole.new()
  mintingAdminRole = await MintingAdminRole.new()
  redemptionAdminRole = await RedemptionAdminRole.new()

  superOwnerMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)
  basicOwnerMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)
  operationAdminMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)

  mintingAdminMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)

  redemptionAdminMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)
  whitelist = await Whitelist.new()
  await whitelist.initialize(operationAdminMultiSig.address)

  mintingReceiverWallet = accounts[9]

  superOwnerRole = await SuperOwnerRole.new()
  await superOwnerRole.initialize(
    superOwnerMultiSig.address,
    mintingReceiverWallet,
  )

  mpv = await MPV.new()

  mpvToken = await MPVToken.new()
  const dailyLimit = 1000 * (10 ** 4) // wei value given token.decimal = 4
  await mpvToken.initialize('Master Property Value', 'MPV', 4, whitelist.address, mpv.address, dailyLimit)

  await mintingAdminRole.initialize(
    mintingAdminMultiSig.address,
    assets.address,
    mpvToken.address,
    superOwnerRole.address
  )

  const receipt = await web3.eth.getTransactionReceipt(mpv.transactionHash)
  console.log(JSON.stringify(receipt, null, 2))


  mpv.initialize(
    mpvToken.address,
    assets.address,
    whitelist.address,
    superOwnerMultiSig.address,
    superOwnerRole.address,
    basicOwnerMultiSig.address,
    operationAdminMultiSig.address,
    mintingAdminMultiSig.address,
    mintingAdminRole.address,
    redemptionAdminMultiSig.address,
  )

  await superOwnerMultiSig.setAdmin(superOwnerMultiSig.address, {
    from: accounts[0],
  })

  await basicOwnerMultiSig.setAdmin(superOwnerMultiSig.address, {
    from: accounts[0],
  })

  await operationAdminMultiSig.setAdmin(basicOwnerMultiSig.address, {
    from: accounts[0],
  })

  await mintingAdminMultiSig.setAdmin(basicOwnerMultiSig.address, {
    from: accounts[0],
  })

  await redemptionAdminMultiSig.setAdmin(basicOwnerMultiSig.address, {
    from: accounts[0],
  })
}

contract('MasterPropertyValue', accounts => {
  describe('SuperOwner', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperOwner = accounts[0]

    it('add 2nd super owner', async () => {
      const newOwner = accounts[2]

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )
      const txId = await superOwnerMultiSig.submitTransaction.call(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      txId.toString().should.equal('0')

      confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(1)

      const required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('1')

      const isConfirmed = await superOwnerMultiSig.isConfirmed.call(txId)
      isConfirmed.should.equal(true)

      const owner = accounts[2]
      const owners = await superOwnerMultiSig.getOwners.call()
      owners.length.should.equal(2)
    })

    it('add 3rd super owner and require 100% of confirmations', async () => {
      let data = encodeCall(
        'changeRequirement',
        ['uint256'],
        [2]
      )
      let txId = await superOwnerMultiSig.submitTransaction.call(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      const required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('2')

      const newOwner = accounts[3]
      data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )
      txId = await superOwnerMultiSig.submitTransaction.call(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      const confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(1)

      let isOwner = await superOwnerMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(false)

      const notASuperOwner = accounts[5]
      await shouldFail(superOwnerMultiSig.confirmTransaction(txId, {
        from: notASuperOwner,
      }))

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      isOwner = await superOwnerMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(true)
    })

    it('remove 2nd and 3rd super owner', async () => {
      let data = encodeCall(
        'removeOwner',
        ['address'],
        [accounts[3]]
      )
      let txId = await superOwnerMultiSig.submitTransaction.call(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      // remove 2nd owner
      data = encodeCall(
        'removeOwner',
        ['address'],
        [accounts[2]]
      )
      txId = await superOwnerMultiSig.submitTransaction.call(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      const required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('1')

      const owners = await superOwnerMultiSig.getOwners.call()
      owners.length.should.equal(1)
    })

    it('set redemption fee', async () => {
      const currentRedemptionFee = await assets.redemptionFee.call()

      currentRedemptionFee.toNumber().should.equal(1000)

      const decimalValue = currentRedemptionFee.toNumber() / (10 ** 4)

      decimalValue.should.equal(0.1)

      const newRedemptionFee = 0.5 * (10 ** 4)

      const data = encodeCall(
        'setRedemptionFee',
        ['uint256'],
        [newRedemptionFee]
      )
      txId = await superOwnerMultiSig.submitTransaction.call(assets.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultSuperOwner,
      })

      const updatedRedemptionFee = await assets.redemptionFee.call()

      updatedRedemptionFee.toNumber().should.equal(newRedemptionFee)
    })

    it('set redemption fee receiver wallet', async () => {
      const currentWallet = await assets.redemptionFeeReceiverWallet.call()
      currentWallet.should.equal('0x0000000000000000000000000000000000000000')

      const newWallet = '0x1111111111111111111111111111111111111111'

      const data = encodeCall(
        'setRedemptionFeeReceiverWallet',
        ['address'],
        [newWallet]
      )
      txId = await superOwnerMultiSig.submitTransaction.call(assets.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultSuperOwner,
      })

      const updatedWallet = await assets.redemptionFeeReceiverWallet.call()

      updatedWallet.should.equal(newWallet)
    })

    it('set token daily limit', async () => {
      const currentLimit = await mpvToken.dailyLimit.call()
      currentLimit.toNumber().should.equal(1000 * (10 ** 4))

      const newLimit = 2000 * (10 * 4)

      const data = encodeCall(
        'setDailyLimit',
        ['uint256'],
        [newLimit]
      )
      txId = await superOwnerMultiSig.submitTransaction.call(mpvToken.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(mpvToken.address, 0, data, {
        from: defaultSuperOwner,
      })

      const updatedLimit = await mpvToken.dailyLimit.call()

      updatedLimit.toNumber().should.equal(newLimit)
    })

    it('set transfer limit countdown length', async () => {
      const currentCountdown = await superOwnerRole.transferLimitChangeCountdownLength.call()
      currentCountdown.toNumber().should.equal(60 * 60 * 24 * 2)

      const newCountdown = 60 * 60 * 24

      const data = encodeCall(
        'setTransferLimitChangeCountdownLength',
        ['uint256'],
        [newCountdown]
      )
      const txId = await superOwnerMultiSig.submitTransaction.call(superOwnerRole.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(superOwnerRole.address, 0, data, {
        from: defaultSuperOwner,
      })

      const updatedCountdown = await superOwnerRole.transferLimitChangeCountdownLength.call()

      updatedCountdown.toNumber().should.equal(newCountdown)
    })
  })

  describe('BasicOwner', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperOwner = accounts[0]

    it('add 2nd basic owner', async () => {
      const newOwner = accounts[2]

      let isOwner = await basicOwnerMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )
      const txId = await superOwnerMultiSig.submitTransaction.call(basicOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(basicOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      isOwner = await basicOwnerMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(true)
    })

    it('remove 2nd basic owner', async () => {
      const owner = accounts[2]
      let isOwner = await basicOwnerMultiSig.isOwner.call(owner)
      isOwner.should.equal(true)

      const data = encodeCall(
        'removeOwner',
        ['address'],
        [owner]
      )
      const txId = await superOwnerMultiSig.submitTransaction.call(basicOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(basicOwnerMultiSig.address, 0, data, {
        from: defaultSuperOwner,
      })

      isOwner = await basicOwnerMultiSig.isOwner.call(owner)
      isOwner.should.equal(false)
    })
  })

  describe('OperationAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicOwner = accounts[0]

    it('add 2nd operation admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await operationAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await operationAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(true)
    })

    it('remove 2nd operation admin', async () => {
      const admin = accounts[2]

      let isOwner = await operationAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(true)

      const data = encodeCall(
        'removeOwner',
        ['address'],
        [admin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await operationAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })
  })

  describe('MintingAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicOwner = accounts[0]

    it('add 2nd mintin admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await mintingAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await mintingAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(true)
    })

    it('remove 2nd minting admin', async () => {
      const admin = accounts[2]

      let isOwner = await mintingAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(true)

      const data = encodeCall(
        'removeOwner',
        ['address'],
        [admin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await mintingAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })
  })

  describe('RedemptionAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicOwner = accounts[0]

    it('add 2nd mintin admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await redemptionAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await redemptionAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(true)
    })

    it('remove 2nd redemption admin', async () => {
      const admin = accounts[2]

      let isOwner = await redemptionAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(true)

      const data = encodeCall(
        'removeOwner',
        ['address'],
        [admin]
      )
      const txId = await basicOwnerMultiSig.submitTransaction.call(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      isOwner = await redemptionAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })
  })

  describe('Whitelist', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultOperationAdmin = accounts[0]

    it('add account to whitelist', async () => {
      const account = accounts[2]

      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)

      await whitelist.addWhitelisted(account, {
        from: defaultOperationAdmin,
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)
    })

    it('instantly remove account from whitelist', async () => {
      const account = accounts[2]

      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)

      await whitelist.removeWhitelisted(account, {
        from: defaultOperationAdmin,
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)
    })
  })

  describe('Pausable', async () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperOwner = accounts[0]

    it('super owner should pause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(false)

      const data = encodeCall(
        'pause',
        [],
        []
      )

      const txId = await superOwnerMultiSig.submitTransaction.call(mpv.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(mpv.address, 0, data, {
        from: defaultSuperOwner,
      })

      paused = await mpv.paused.call()
      paused.should.equal(true)
    })

    it('super owner should unpause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(true)

      const data = encodeCall(
        'unpause',
        [],
        []
      )

      const txId = await superOwnerMultiSig.submitTransaction.call(mpv.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(mpv.address, 0, data, {
        from: defaultSuperOwner,
      })

      paused = await mpv.paused.call()
      paused.should.equal(false)
    })
  })

  describe('Assets', () => {
    const defaultSuperOwner = accounts[0]
    const defaultBasicOwner = accounts[0]
    const defaultMintingAdmin = accounts[0]
    const defaultOperationAdmin = accounts[0]
    const secondMintingAdmin = accounts[2]

    beforeEach(async () => {
      await initContracts(accounts)

      let data = encodeCall(
        'setMintingActionCountdown',
        ['uint256'],
        [1]
      )

      let txId = await superOwnerMultiSig.submitTransaction.call(mintingAdminRole.address, 0, data, {
        from: defaultSuperOwner,
      })
      await superOwnerMultiSig.submitTransaction(mintingAdminRole.address, 0, data, {
        from: defaultSuperOwner,
      })

      const countdown = await mintingAdminRole.mintingActionCountdownLength.call()
      countdown.toNumber().should.equal(1)

      let admins = await mintingAdminMultiSig.getOwners.call()
      admins.length.should.equal(1)

      data = encodeCall(
        'addOwner',
        ['address'],
        [secondMintingAdmin]
      )

      txId = await basicOwnerMultiSig.submitTransaction.call(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      data = encodeCall(
        'changeRequirement',
        ['uint256'],
        [2]
      )
      txId = await basicOwnerMultiSig.submitTransaction.call(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })
      await basicOwnerMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicOwner,
      })

      const required = await mintingAdminMultiSig.required.call({
        from: defaultBasicOwner,
      })
      required.toNumber().should.equal(2)

      admins = await mintingAdminMultiSig.getOwners.call()
      admins.length.should.equal(2)

      await whitelist.addWhitelisted(mintingReceiverWallet, {
        from: defaultOperationAdmin,
      })

      await whitelist.addWhitelisted(mintingAdminRole.address, {
        from: defaultOperationAdmin,
      })
    })

    it('add pending asset and start countdown', async () => {
      let asset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
        statusEvents: [],
      }

      let pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(0)

      const txId = await mintingAdminRole.addPendingAsset.call(asset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(asset, {
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(1)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondMintingAdmin,
      })

      const countdownStart = await mintingAdminRole.mintingCountdownStart.call()
      countdownStart.toString().should.not.equal('0')

      /*
      asset.id = 2
      // countdown started; can't add new assets
      await shouldFail(addAsset(asset, {
        from: defaultMintingAdmin,
      }))
      */

      await mine(60)

      await mintingAdminRole.refreshPendingAssetsStatus({
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(0)

      asset = await assets.get.call(1)
      asset.tokens.should.equal('100')
    })

    /*
    it.skip('reset pending asset votes', async () => {
      const asset = {
        id: 11,
        notarizationId: '0xabcd',
        tokens: 100,
      }

      const txId = await addAsset(asset, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      let pendingAssetsCount = await mpv.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(1)

      const secondAsset = {
        id: 12,
        notarizationId: '0xabcd',
        tokens: 100,
      }

      await addAsset(secondAsset, {
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(2)

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)
    })

    it.skip('add multiple pending assets, remove pending asset', async () => {
      const assets = [{
        id: 2,
        notarizationId: '0xabcd',
        tokens: 100,
      }, {
        id: 3,
        notarizationId: '0x1234',
        tokens: 100,
      }]

      const txId = await mpv.addPendingAssets.call(assets, {
        from: defaultMintingAdmin,
      })
      await mpv.addPendingAssets(assets, {
        from: defaultMintingAdmin,
      })

      let pendingAssetsCount = await mpv.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(2)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      const assetId = 2
      await invoke(
        Actions.removePendingAsset,
        Roles.MintingAdmin,
        [assetId],
        [],
        [],
        {
          from: defaultMintingAdmin,
        })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(1)

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondMintingAdmin,
      })

      await mine(60)

      await invoke(
        Actions.updatePendingAssetsStatus,
        Roles.MintingAdmin,
        [],
        [],
        [],
        {
          from: accounts[0],
        })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(0)
    })

    it.skip('cancel minting', async () => {
      const asset = {
        id: 10,
        notarizationId: '0xabcd',
        tokens: 100,
      }

      const txId = await addAsset(asset, {
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(1)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(2)

      let countdownStart = await mpv.mintingCountownStart.call()
      countdownStart.toString().should.not.equal('0')

      const notABasicOwner = accounts[3]
      await shouldFail(invoke(
        Actions.cancelMinting,
        Roles.BasicOwner,
        [],
        [],
        [],
        {
          from: notABasicOwner,
        }))

      await invoke(
        Actions.cancelMinting,
        Roles.BasicOwner,
        [],
        [],
        [],
        {
          from: defaultBasicOwner,
        })

      countdownStart = await mpv.mintingCountownStart.call()
      countdownStart.toString().should.equal('0')

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)
    })
    */
  })
})
