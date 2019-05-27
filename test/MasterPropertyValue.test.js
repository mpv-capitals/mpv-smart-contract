const { shouldFail } = require('openzeppelin-test-helpers')
const { encodeCall } = require('zos-lib')
const moment = require('moment')
const { Status, mine } = require('./helpers')

require('chai').should()

const MPV = artifacts.require('MasterPropertyValue')
const MPVToken = artifacts.require('MPVToken')
const Assets = artifacts.require('Assets')
const Whitelist = artifacts.require('Whitelist')
const AdministeredMultiSigWallet = artifacts.require('AdministeredMultiSigWallet')
const SuperProtectorRole = artifacts.require('SuperProtectorRole')
const BasicProtectorRole = artifacts.require('BasicProtectorRole')
const MintingAdminRole = artifacts.require('MintingAdminRole')
const RedemptionAdminRole = artifacts.require('RedemptionAdminRole')

let mpv = null
let mpvToken = null
let assets = null
let whitelist = null

let superProtectorRole = null
let basicProtectorRole = null
let mintingAdminRole = null
let redemptionAdminRole = null

let superProtectorMultiSig = null
let basicProtectorMultiSig = null
let operationAdminMultiSig = null
let mintingAdminMultiSig = null
let redemptionAdminMultiSig = null

let mintingReceiverWallet = null
let redemptionFeeReceiverWallet = null

async function initContracts (accounts) {
  mintingReceiverWallet = accounts[8]
  redemptionFeeReceiverWallet = accounts[9]

  mpv = await MPV.new()
  mpvToken = await MPVToken.new()
  assets = await Assets.new()
  whitelist = await Whitelist.new()

  superProtectorRole = await SuperProtectorRole.new()
  basicProtectorRole = await BasicProtectorRole.new()
  mintingAdminRole = await MintingAdminRole.new()
  redemptionAdminRole = await RedemptionAdminRole.new()

  superProtectorMultiSig = await AdministeredMultiSigWallet.new()
  superProtectorMultiSig.initialize([accounts[0]], 1)
  basicProtectorMultiSig = await AdministeredMultiSigWallet.new()
  basicProtectorMultiSig.initialize([accounts[0]], 1)
  operationAdminMultiSig = await AdministeredMultiSigWallet.new()
  operationAdminMultiSig.initialize([accounts[0]], 1)
  mintingAdminMultiSig = await AdministeredMultiSigWallet.new()
  mintingAdminMultiSig.initialize([accounts[0]], 1)
  redemptionAdminMultiSig = await AdministeredMultiSigWallet.new()
  redemptionAdminMultiSig.initialize([accounts[0]], 1)

  await whitelist.initialize(
    operationAdminMultiSig.address,
    basicProtectorMultiSig.address,
    mpv.address
  )

  await mpvToken.initialize(
    'Master Property Value',
    'MPV',
    18,
    whitelist.address,
    mpv.address,
    mintingAdminRole.address,
    redemptionAdminRole.address,
    accounts[5] // super protector multisig
  )

  await assets.initialize(
    1000,
    redemptionFeeReceiverWallet,
    mintingAdminRole.address,
    redemptionAdminRole.address,
    redemptionAdminMultiSig.address,
    basicProtectorMultiSig.address,
    mpvToken.address,
    mpv.address
  )

  await superProtectorRole.initialize(
    superProtectorMultiSig.address,
    mpv.address
  )

  await basicProtectorRole.initialize(
    basicProtectorMultiSig.address
  )

  await mintingAdminRole.initialize(
    mintingAdminMultiSig.address,
    assets.address,
    mpvToken.address,
    superProtectorRole.address,
    basicProtectorRole.address,
    mintingReceiverWallet,
    mpv.address
  )

  await mpv.initialize(
    mpvToken.address,
    assets.address,
    whitelist.address,
  )

  await superProtectorMultiSig.updateAdmin(superProtectorMultiSig.address)
  await basicProtectorMultiSig.updateAdmin(superProtectorMultiSig.address)
  await operationAdminMultiSig.updateAdmin(basicProtectorMultiSig.address)
  await mintingAdminMultiSig.updateTransactor(mintingAdminRole.address)
  await mintingAdminMultiSig.updateAdmin(basicProtectorMultiSig.address)
  await redemptionAdminMultiSig.updateTransactor(assets.address)
  await redemptionAdminMultiSig.updateAdmin(basicProtectorMultiSig.address)
  await mpv.updatePausableAdmin(superProtectorMultiSig.address)
}

contract('MasterPropertyValue', accounts => {
  describe('SuperProtector', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperProtector = accounts[0]
    const defaultBasicProtector = accounts[0]

    it('add 2nd super owner', async () => {
      const newOwner = accounts[2]

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )

      const txId = await superProtectorMultiSig.submitTransaction.call(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      const notASuperProtector = accounts[9]
      await shouldFail(superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: notASuperProtector,
      }))

      txId.toString().should.equal('0')

      const confirmationCount = await superProtectorMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(1)

      const required = await superProtectorMultiSig.required.call()
      required.toString().should.equal('1')

      const isConfirmed = await superProtectorMultiSig.isConfirmed.call(txId)
      isConfirmed.should.equal(true)

      const owners = await superProtectorMultiSig.getOwners.call()
      owners.length.should.equal(2)
    })

    it('add 3rd super protector and require 100% of confirmations', async () => {
      let data = encodeCall(
        'changeRequirement',
        ['uint256'],
        [2]
      )
      let txId = await superProtectorMultiSig.submitTransaction.call(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      const required = await superProtectorMultiSig.required.call()
      required.toString().should.equal('2')

      const newOwner = accounts[3]
      data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )
      txId = await superProtectorMultiSig.submitTransaction.call(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      const confirmationCount = await superProtectorMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(1)

      let isOwner = await superProtectorMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(false)

      const notASuperProtector = accounts[9]
      await shouldFail(superProtectorMultiSig.confirmTransaction(txId, {
        from: notASuperProtector,
      }))

      await superProtectorMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      isOwner = await superProtectorMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(true)

      // should not be able to confirm transaction again
      await shouldFail(superProtectorMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      }))
    })

    it('remove 2nd and 3rd super owner', async () => {
      let data = encodeCall(
        'removeOwner',
        ['address'],
        [accounts[3]]
      )
      let txId = await superProtectorMultiSig.submitTransaction.call(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      await superProtectorMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      // remove 2nd owner
      data = encodeCall(
        'removeOwner',
        ['address'],
        [accounts[2]]
      )
      txId = await superProtectorMultiSig.submitTransaction.call(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      await superProtectorMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      const required = await superProtectorMultiSig.required.call()
      required.toString().should.equal('1')

      let owners = await superProtectorMultiSig.getOwners.call()
      owners.length.should.equal(1)

      data = encodeCall(
        'removeOwner',
        ['address'],
        [defaultSuperProtector]
      )

      // should not be able to delete sole owner
      await superProtectorMultiSig.submitTransaction(superProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      owners = await superProtectorMultiSig.getOwners.call()
      owners.length.should.equal(1)
    })

    it('reverts if redemption fee receiver wallet set to empty', async () => {
      const currentWallet = await assets.redemptionFeeReceiverWallet.call()
      const newWallet = '0x0000000000000000000000000000000000000000'

      const data = encodeCall(
        'updateRedemptionFeeReceiverWallet',
        ['address'],
        [newWallet]
      )

      basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      const updatedWallet = await assets.redemptionFeeReceiverWallet.call()
      updatedWallet.should.equal(currentWallet)
    })

    it('set transfer limit countdown length', async () => {
      const currentCountdown = await superProtectorRole.transferLimitChangeCountdownLength.call()
      currentCountdown.toNumber().should.equal(60 * 60 * 24 * 2)

      const newCountdown = 60 * 60 * 24

      const data = encodeCall(
        'updateTransferLimitChangeCountdownLength',
        ['uint256'],
        [newCountdown]
      )
      await superProtectorMultiSig.submitTransaction(superProtectorRole.address, 0, data, {
        from: defaultSuperProtector,
      })

      const updatedCountdown = await superProtectorRole.transferLimitChangeCountdownLength.call()

      updatedCountdown.toNumber().should.equal(newCountdown)
    })

    it('set burning action countdown', async () => {
      const newCountdown = 60 * 60 * 24

      const data = encodeCall(
        'updateTransferLimitChangeCountdownLength',
        ['uint256'],
        [newCountdown]
      )
      await superProtectorMultiSig.submitTransaction(superProtectorRole.address, 0, data, {
        from: defaultSuperProtector,
      })

      const updatedCountdown = await superProtectorRole.transferLimitChangeCountdownLength.call()

      updatedCountdown.toNumber().should.equal(newCountdown)
    })

    it('set redemption admin whitelist removal action countdown', async () => {
      const newCountdown = 60 * 60 * 24

      const data = encodeCall(
        'updateWhitelistRemovalActionCountdownLength',
        ['uint256'],
        [newCountdown]
      )
      await superProtectorMultiSig.submitTransaction(superProtectorRole.address, 0, data, {
        from: defaultSuperProtector,
      })

      const updatedCountdown = await superProtectorRole.whitelistRemovalActionCountdownLength.call()

      updatedCountdown.toNumber().should.equal(newCountdown)
    })

    it('set countdown length for delayed transfer', async () => {
      const newCountdown = 60 * 60 * 24

      const data = encodeCall(
        'updateDelayedTransferCountdownLength',
        ['uint256'],
        [newCountdown]
      )
      await superProtectorMultiSig.submitTransaction(superProtectorRole.address, 0, data, {
        from: defaultSuperProtector,
      })

      const updatedCountdown = await superProtectorRole.delayedTransferCountdownLength.call()

      updatedCountdown.toNumber().should.equal(newCountdown)
    })
  })

  describe('BasicOwner', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperProtector = accounts[0]
    const defaultBasicProtector = accounts[0]

    it('add 2nd basic owner', async () => {
      const newOwner = accounts[2]

      let isOwner = await basicProtectorMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newOwner]
      )
      await superProtectorMultiSig.submitTransaction(basicProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      isOwner = await basicProtectorMultiSig.isOwner.call(newOwner)
      isOwner.should.equal(true)
    })

    it('remove 2nd basic owner', async () => {
      const owner = accounts[2]
      let isOwner = await basicProtectorMultiSig.isOwner.call(owner)
      isOwner.should.equal(true)

      const data = encodeCall(
        'removeOwner',
        ['address'],
        [owner]
      )
      await superProtectorMultiSig.submitTransaction(basicProtectorMultiSig.address, 0, data, {
        from: defaultSuperProtector,
      })

      isOwner = await basicProtectorMultiSig.isOwner.call(owner)
      isOwner.should.equal(false)
    })

    it('set redemption fee', async () => {
      const currentRedemptionFee = await assets.redemptionFee.call()
      currentRedemptionFee.toNumber().should.equal(1000)

      const decimalValue = currentRedemptionFee.toNumber() / (10 ** 4)
      decimalValue.should.equal(0.1)

      const newRedemptionFee = 0.5 * (10 ** 4)
      const data = encodeCall(
        'updateRedemptionFee',
        ['uint256'],
        [newRedemptionFee]
      )
      await basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      const updatedRedemptionFee = await assets.redemptionFee.call()
      updatedRedemptionFee.toNumber().should.equal(newRedemptionFee)
    })

    it('set redemption fee receiver wallet', async () => {
      const currentWallet = redemptionFeeReceiverWallet
      currentWallet.should.equal(redemptionFeeReceiverWallet)
      const newWallet = '0x1111111111111111111111111111111111111111'

      const data = encodeCall(
        'updateRedemptionFeeReceiverWallet',
        ['address'],
        [newWallet]
      )
      await basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      const updatedWallet = await assets.redemptionFeeReceiverWallet.call()

      updatedWallet.should.equal(newWallet)
    })
  })

  describe('OperationAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicProtector = accounts[0]

    it('add 2nd operation admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await operationAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      await basicProtectorMultiSig.submitTransaction(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
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
      await basicProtectorMultiSig.submitTransaction(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      isOwner = await operationAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })

    it('add account to whitelist', async () => {
      const admin = accounts[2]
      const data = encodeCall(
        'addOwner',
        ['address'],
        [admin]
      )
      await basicProtectorMultiSig.submitTransaction(operationAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      const account = accounts[3]
      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)

      await whitelist.addWhitelisted(account, {
        from: admin,
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)
    })

    it('add multiple accounts to whitelist at once', async () => {
      const admin = accounts[2]

      const whitelisteds = [accounts[4], accounts[5]]
      let isWhitelisted = await whitelist.isWhitelisted.call(whitelisteds[1])
      isWhitelisted.should.equal(false)

      await whitelist.addWhitelisteds(whitelisteds, {
        from: admin,
      })

      isWhitelisted = await whitelist.isWhitelisted.call(whitelisteds[1])
      isWhitelisted.should.equal(true)
    })

    it('basic protector remove account from whitelist', async () => {
      const basicProtector = accounts[0]
      const account = accounts[4]

      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)

      const data = encodeCall(
        'removeWhitelisted',
        ['address'],
        [account]
      )
      await basicProtectorMultiSig.submitTransaction(whitelist.address, 0, data, {
        from: basicProtector,
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)
    })
  })

  describe('MintingAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicProtector = accounts[0]

    it('add 2nd mintin admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await mintingAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      await basicProtectorMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
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
      await basicProtectorMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      isOwner = await mintingAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })
  })

  describe('RedemptionAdmin', () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultBasicProtector = accounts[0]

    it('add 2nd mintin admin', async () => {
      const newAdmin = accounts[2]

      let isOwner = await redemptionAdminMultiSig.isOwner.call(newAdmin)
      isOwner.should.equal(false)

      const data = encodeCall(
        'addOwner',
        ['address'],
        [newAdmin]
      )
      await basicProtectorMultiSig.submitTransaction(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
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
      await basicProtectorMultiSig.submitTransaction(redemptionAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      isOwner = await redemptionAdminMultiSig.isOwner.call(admin)
      isOwner.should.equal(false)
    })
  })

  describe('Pausable', async () => {
    before(async () => {
      await initContracts(accounts)
    })

    const defaultSuperProtector = accounts[0]

    it('super owner should pause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(false)

      // must happen through multisig
      await shouldFail(mpv.pause({
        from: defaultSuperProtector,
      }))

      const data = encodeCall(
        'pause',
        [],
        []
      )

      await superProtectorMultiSig.submitTransaction(mpv.address, 0, data, {
        from: defaultSuperProtector,
      })

      paused = await mpv.paused.call()
      paused.should.equal(true)
    })

    it('super owner should unpause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(true)

      await shouldFail(mpv.unpause({
        from: defaultSuperProtector,
      }))

      const data = encodeCall(
        'unpause',
        [],
        []
      )

      await superProtectorMultiSig.submitTransaction(mpv.address, 0, data, {
        from: defaultSuperProtector,
      })

      paused = await mpv.paused.call()
      paused.should.equal(false)
    })
  })

  describe('Assets', () => {
    const defaultSuperProtector = accounts[0]
    const defaultBasicProtector = accounts[0]
    const defaultMintingAdmin = accounts[0]
    const defaultOperationAdmin = accounts[0]
    const secondMintingAdmin = accounts[2]

    beforeEach(async () => {
      await initContracts(accounts)

      let data = encodeCall(
        'updateMintingActionCountdownLength',
        ['uint256'],
        [1]
      )

      await superProtectorMultiSig.submitTransaction(mintingAdminRole.address, 0, data, {
        from: defaultSuperProtector,
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

      await basicProtectorMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      data = encodeCall(
        'changeRequirement',
        ['uint256'],
        [2]
      )
      await basicProtectorMultiSig.submitTransaction(mintingAdminMultiSig.address, 0, data, {
        from: defaultBasicProtector,
      })

      const required = await mintingAdminMultiSig.required.call({
        from: defaultBasicProtector,
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
      asset.tokens.toNumber().should.equal(100)
    })

    it('reset pending asset votes', async () => {
      const asset = {
        id: 11,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      let pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(0)

      let txId = await mintingAdminRole.addPendingAsset.call(asset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(asset, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      pendingAssetsCount = await assets.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(1)

      const secondAsset = {
        id: 12,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      txId = await mintingAdminRole.addPendingAsset.call(secondAsset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(asset, {
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(2)

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)
    })

    it('add multiple pending assets, remove pending asset', async () => {
      const list = [{
        id: 2,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }, {
        id: 3,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }]

      let txId = await mintingAdminRole.addPendingAssets.call(list, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAssets(list, {
        from: defaultMintingAdmin,
      })

      let pendingAssetsCount = await assets.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(2)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      const assetId = 2
      txId = await mintingAdminRole.removePendingAsset.call(assetId, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.removePendingAsset(assetId, {
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await assets.pendingAssetsCount.call({
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

      await mintingAdminRole.refreshPendingAssetsStatus({
        from: defaultMintingAdmin,
      })

      pendingAssetsCount = await assets.pendingAssetsCount.call({
        from: accounts[0],
      })
      pendingAssetsCount.toNumber().should.equal(0)
    })

    it('cancel minting', async () => {
      const asset = {
        id: 10,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      const txId = await mintingAdminRole.addPendingAsset.call(asset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(asset, {
        from: defaultMintingAdmin,
      })

      const pendingAssetsCount = await assets.pendingAssetsCount.call({
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

      let countdownStart = await mintingAdminRole.mintingCountdownStart.call()
      countdownStart.toString().should.not.equal('0')

      const notABasicOwner = accounts[3]
      await shouldFail(mintingAdminRole.cancelMinting({
        from: notABasicOwner,
      }))

      await mintingAdminRole.cancelMinting({
        from: defaultBasicProtector,
      })

      countdownStart = await mintingAdminRole.mintingCountdownStart.call()
      countdownStart.toString().should.equal('0')

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)
    })

    it('set asset to from enlisted to reserved status', async () => {
      const newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }
      const txId = await mintingAdminRole.addPendingAsset.call(newAsset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(newAsset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })
      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondMintingAdmin,
      })

      await mine(60)

      await mintingAdminRole.refreshPendingAssetsStatus({
        from: defaultMintingAdmin,
      })
      let asset = await assets.get.call(1)
      asset.status.toNumber().should.equal(Status.Enlisted)

      const data = encodeCall(
        'setReserved',
        ['uint256[]'],
        [[1]]
      )

      await basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      asset = await assets.get.call(1)
      asset.status.toNumber().should.equal(Status.Reserved)
    })

    it('set asset from reserved to enlisted status', async () => {
      const newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }
      const txId = await mintingAdminRole.addPendingAsset.call(newAsset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminRole.addPendingAsset(newAsset, {
        from: defaultMintingAdmin,
      })
      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })
      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondMintingAdmin,
      })

      await mine(60)
      await mintingAdminRole.refreshPendingAssetsStatus({
        from: defaultMintingAdmin,
      })

      let data = encodeCall(
        'setReserved',
        ['uint256[]'],
        [[1]]
      )

      await basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      let asset = await assets.get.call(1)
      asset.status.toNumber().should.equal(Status.Reserved)

      data = encodeCall(
        'setEnlisted',
        ['uint256[]'],
        [[1]]
      )

      await basicProtectorMultiSig.submitTransaction(assets.address, 0, data, {
        from: defaultBasicProtector,
      })

      asset = await assets.get.call(1)
      asset.status.toNumber().should.equal(Status.Enlisted)
    })
  })
})
