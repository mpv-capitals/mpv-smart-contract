const { shouldFail } = require('openzeppelin-test-helpers')
const { Actions, Roles }  = require('./helpers')

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

const SuperOwnerMultiSigWallet = artifacts.require('SuperOwnerMultiSigWallet')
const BasicOwnerMultiSigWallet = artifacts.require('BasicOwnerMultiSigWallet')
const OperationAdminMultiSigWallet = artifacts.require('OperationAdminMultiSigWallet')
const MintingAdminMultiSigWallet = artifacts.require('MintingAdminMultiSigWallet')
const RedemptionAdminMultiSigWallet = artifacts.require('RedemptionAdminMultiSigWallet')
const Whitelist = artifacts.require('Whitelist')

contract('MasterPropertyValue', accounts => {
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

  async function invoke(action, role, uint256Args, addressArgs, options) {
      const args = {
        role,
        uint256Args,
        addressArgs,
      }
      const txId = await mpv.invoke.call(action, args, options)
      await mpv.invoke(action, args, options)

      return txId
  }

  before(async () => {
    assets = await Assets.new()
    mpvState = await MPVState.new()
    superOwnerRole = await SuperOwnerRole.new()
    basicOwnerRole = await BasicOwnerRole.new()
    operationAdminRole = await OperationAdminRole.new()
    mintingAdminRole = await MintingAdminRole.new()
    redemptionAdminRole = await RedemptionAdminRole.new()

    superOwnerMultiSig = await SuperOwnerMultiSigWallet.new([accounts[0]], 1)
    basicOwnerMultiSig = await BasicOwnerMultiSigWallet.new([accounts[0]], 1)
    operationAdminMultiSig = await OperationAdminMultiSigWallet.new([accounts[0]], 1)
    mintingAdminMultiSig = await MintingAdminMultiSigWallet.new([accounts[0]], 1)
    redemptionAdminMultiSig = await RedemptionAdminMultiSigWallet.new([accounts[0]], 1)
    whitelist = await Whitelist.new()
    await whitelist.initialize(operationAdminMultiSig.address)

    await MPV.link({
      Assets: assets.address,
      MPVState: mpvState.address,
      SuperOwnerRole: superOwnerRole.address,
      BasicOwnerRole: basicOwnerRole.address,
      OperationAdminRole: operationAdminRole.address,
      MintingAdminRole: mintingAdminRole.address,
      RedemptionAdminRole: redemptionAdminRole.address
    })

    const mintingReceiverWalletAddress = '0x0000000000000000000000000000000000000000'

    mpv = await MPV.new()

    const receipt = await web3.eth.getTransactionReceipt(mpv.transactionHash)
    console.log(JSON.stringify(receipt, null, 2))

    mpvToken = await MPVToken.new()
    await mpvToken.initialize('Master Property Value', 'MPV', 4, whitelist.address, mpv.address)

    mpv.initialize(
      mpvToken.address,
      superOwnerMultiSig.address,
      basicOwnerMultiSig.address,
      operationAdminMultiSig.address,
      mintingAdminMultiSig.address,
      redemptionAdminMultiSig.address,
      whitelist.address,
      mintingReceiverWalletAddress,
      1000 * (10 ** 4) // dailyTransferLimit: wei value given token.decimal = 4
    )

    await superOwnerMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })

    await basicOwnerMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })

    await operationAdminMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })

    await mintingAdminMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })

    await redemptionAdminMultiSig.setMPV(mpv.address, {
      from: accounts[0],
    })
  })

  describe('SuperOwnerMultiSig', () => {
    const defaultSuperOwner = accounts[0]

    it('add 2nd super owner', async () => {
      const newOwner = accounts[2]
      const txId = await invoke(
        Actions.addOwner,
        Roles.SuperOwner,
        [],
        [newOwner],
        {
        from: defaultSuperOwner
      })

      txId.toString().should.equal('0')

      let confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(0)

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(1)

      const required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('1')

      const isConfirmed = await superOwnerMultiSig.isConfirmed.call('0')
      isConfirmed.should.equal(true)

      const owner = accounts[2]
      const owners = await superOwnerMultiSig.getOwners.call()
      owners.length.should.equal(2)
      const res = await mpv.isOwner.call(Roles.SuperOwner, owner)
      res.should.equal(true)
    })

    it('add 3rd super owner and require 100% of confirmations', async () => {
      let count = await mpv.getOwners.call(Roles.SuperOwner)
      count.length.should.equal(2)

      let threshold = await mpv.superOwnerActionThresholdPercent.call()
      threshold.toString().should.equal('40')

      let txId = await invoke(
        Actions.setSuperOwnerActionThresholdPercent,
        Roles.SuperOwner,
        [100],
        [],
        {
        from: defaultSuperOwner
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      threshold = await mpv.superOwnerActionThresholdPercent.call()
      threshold.toString().should.equal('100')

      let required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('2')

      const newOwner = accounts[3]

      txId = await invoke(
        Actions.addOwner,
        Roles.SuperOwner,
        [],
        [newOwner],
        {
        from: defaultSuperOwner
      })

      const confirmationCount = await superOwnerMultiSig.getConfirmations.call(txId)
      confirmationCount.length.should.equal(0)

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      let isOwner = await mpv.isOwner.call(Roles.SuperOwner, newOwner)
      isOwner.should.equal(false)

      const notASuperOwner = accounts[1]
      await shouldFail(superOwnerMultiSig.confirmTransaction(txId, {
        from: notASuperOwner,
      }))

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('3')

      isOwner = await mpv.isOwner.call(Roles.SuperOwner, newOwner)
      isOwner.should.equal(true)

      count = await mpv.getOwners.call(Roles.SuperOwner)
      count.length.should.equal(3)
    })

    it('remove 2nd and 3rd super owner', async () => {
      const owner = accounts[3]

      let isOwner = await mpv.isOwner.call(Roles.SuperOwner, owner)
      isOwner.should.equal(true)

      // remove 3rd owner
      let txId = await invoke(
        Actions.removeOwner,
        Roles.SuperOwner,
        [],
        [owner],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: owner,
      })

      isOwner = await mpv.isOwner.call(Roles.SuperOwner, owner)
      isOwner.should.equal(false)

      const count = await mpv.getOwners.call(Roles.SuperOwner)
      count.length.should.equal(2)

      let required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('2')

      // remove 2nd owner
      txId = await invoke(
        Actions.removeOwner,
        Roles.SuperOwner,
        [],
        [accounts[2]],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[2],
      })

      required = await superOwnerMultiSig.required.call()
      required.toString().should.equal('1')
    })

    it('set redemption fee', async () => {
      const currentRedemptionFee = await mpv.redemptionFee.call()

      currentRedemptionFee.toNumber().should.equal(1000)

      const decimalValue = currentRedemptionFee.toNumber() / (10 ** 4)

      decimalValue.should.equal(0.1)

      const newRedemptionFee = 0.5 * (10 ** 4)

      const txId = await invoke(
        Actions.setRedemptionFee,
        Roles.SuperOwner,
        [newRedemptionFee],
        [],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      const updatedRedemptionFee = await mpv.redemptionFee.call()

      updatedRedemptionFee.toNumber().should.equal(newRedemptionFee)
    })

    it('set redemption fee receiver wallet', async () => {
      const currentWallet = await mpv.redemptionFeeReceiverWallet.call()
      currentWallet.should.equal('0x0000000000000000000000000000000000000000')

      const newWallet = '0x1111111111111111111111111111111111111111'

      const txId = await invoke(
        Actions.setRedemptionFeeReceiverWallet,
        Roles.SuperOwner,
        [],
        [newWallet],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      const updatedWallet = await mpv.redemptionFeeReceiverWallet.call()

      updatedWallet.should.equal(newWallet)
    })
  })

  describe('BasicOwnerMultiSig', () => {
    const defaultSuperOwner = accounts[0]

    it('add 2nd basic owner', async () => {
      const newOwner = accounts[2]

      let isOwner = await mpv.isOwner.call(Roles.BasicOwner, newOwner)
      isOwner.should.equal(false)

      const txId = await invoke(
        Actions.addOwner,
        Roles.BasicOwner,
        [],
        [newOwner],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      isOwner = await mpv.isOwner.call(Roles.BasicOwner, newOwner)
      isOwner.should.equal(true)
    })

    it('remove 2nd basic owner', async () => {
      const owner = accounts[2]

      let isOwner = await mpv.isOwner.call(Roles.BasicOwner, owner)
      isOwner.should.equal(true)

      const txId = await invoke(
        Actions.removeOwner,
        Roles.BasicOwner,
        [],
        [owner],
      {
        from: defaultSuperOwner,
      })

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: defaultSuperOwner,
      })

      isOwner = await mpv.isOwner.call(Roles.BasicOwner, owner)
      isOwner.should.equal(false)
    })
  })

  describe('OperationAdminMultiSig', () => {
    const defaultBasicOwner = accounts[0]
    it('add 2nd operation admin', async () => {
      const newAdmin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.OperationAdmin, newAdmin)
      isAdmin.should.equal(false)

      const txId = await invoke(
        Actions.addOwner,
        Roles.OperationAdmin,
        [],
        [newAdmin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: defaultBasicOwner,
      })

      isAdmin = await mpv.isOwner.call(Roles.OperationAdmin, newAdmin)
      isAdmin.should.equal(true)
    })

    it('remove 2nd operation admin', async () => {
      const admin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.OperationAdmin, admin)
      isAdmin.should.equal(true)

      const txId = await invoke(
        Actions.removeOwner,
        Roles.OperationAdmin,
        [],
        [admin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: defaultBasicOwner,
      })

      isAdmin = await mpv.isOwner.call(Roles.OperationAdmin, admin)
      isAdmin.should.equal(false)
    })
  })

  describe('MintingAdminMultiSig', () => {
    const defaultBasicOwner = accounts[0]

    it('add 2nd minting admin', async () => {
      const newAdmin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.MintingAdmin, newAdmin)
      isAdmin.should.equal(false)

      const txId = await invoke(
        Actions.addOwner,
        Roles.MintingAdmin,
        [],
        [newAdmin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      isAdmin = await mpv.isOwner.call(Roles.MintingAdmin, newAdmin)
      isAdmin.should.equal(true)
    })

    it('remove 2nd minting admin', async () => {
      const admin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.MintingAdmin, admin)
      isAdmin.should.equal(true)

      const txId = await invoke(
        Actions.removeOwner,
        Roles.MintingAdmin,
        [],
        [admin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      isAdmin = await mpv.isOwner.call(Roles.MintingAdmin, admin)
      isAdmin.should.equal(false)
    })
  })

  describe('RedemptionAdminMultiSig', () => {
    const defaultBasicOwner = accounts[0]

    it('add 2nd redemption admin', async () => {
      const newAdmin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.RedemptionAdmin, newAdmin)
      isAdmin.should.equal(false)

      const txId = await invoke(
        Actions.addOwner,
        Roles.RedemptionAdmin,
        [],
        [newAdmin],
      {
        from: defaultBasicOwner,
      })

      const notABasicOwner = accounts[1]
      await shouldFail(basicOwnerMultiSig.confirmTransaction(txId, {
        from: notABasicOwner,
      }))

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      isAdmin = await mpv.isOwner.call(Roles.RedemptionAdmin, newAdmin)
      isAdmin.should.equal(true)
    })

    it('remove 2nd redemption admin', async () => {
      const admin = accounts[2]

      let isAdmin = await mpv.isOwner.call(Roles.RedemptionAdmin, admin)
      isAdmin.should.equal(true)

      const txId = await invoke(
        Actions.removeOwner,
        Roles.RedemptionAdmin,
        [],
        [admin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      isAdmin = await mpv.isOwner.call(Roles.RedemptionAdmin, admin)
      isAdmin.should.equal(false)
    })
  })

  it('Pausable', async () => {
    it('super owner should pause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(false)

      const txId = await mpv.pauseContract.call({
        from: accounts[0],
      })
      await mpv.pauseContract({
        from: accounts[0],
      })

      const notASuperOwner = accounts[1]
      await shouldFail(superOwnerMultiSig.confirmTransaction(txId, {
        from: notASuperOwner,
      }))

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      paused = await mpv.paused.call()
      paused.should.equal(true)
    })

    it('super owner should unpause contract', async () => {
      let paused = await mpv.paused.call()
      paused.should.equal(true)

      const txId = await mpv.unpauseContract.call({
        from: accounts[0],
      })
      await mpv.unpauseContract({
        from: accounts[0],
      })

      const notASuperOwner = accounts[1]
      await shouldFail(superOwnerMultiSig.confirmTransaction(txId, {
        from: notASuperOwner,
      }))

      await superOwnerMultiSig.confirmTransaction(txId, {
        from: accounts[0],
      })

      paused = await mpv.paused.call()
      paused.should.equal(false)
    })
  })

  describe('Whitelist', () => {
    const defaultOperationAdmin = accounts[0]

    it('add account to whitelist', async () => {
      const account = accounts[2]

      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)

      await whitelist.addWhitelisted(account, {
        from: defaultOperationAdmin
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)
    })

    it('instantly remove account from whitelist', async () => {
      const account = accounts[2]

      let isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(true)

      await whitelist.removeWhitelisted(account, {
        from: defaultOperationAdmin
      })

      isWhitelisted = await whitelist.isWhitelisted.call(account)
      isWhitelisted.should.equal(false)
    })
  })

  // TODO
  describe.skip('Asset', () => {
    const defaultBasicOwner = accounts[0]
    const defaultMintingAdmin = accounts[0]
    const secondAdmin = accounts[2]

    before(async () => {
      let admins = await mpv.getOwners.call(Roles.MintingAdmin)
      admins.length.should.equal(1)

      const txId = await invoke(
        Actions.addOwner,
        Roles.MintingAdmin,
        [],
        [secondAdmin],
      {
        from: defaultBasicOwner,
      })

      await basicOwnerMultiSig.confirmTransaction(txId, {
        from: defaultBasicOwner
      })

      const required = await mintingAdminMultiSig.required.call({
        from: defaultBasicOwner
      })
      required.toNumber().should.equal(2)

      admins = await mpv.getOwners.call(Roles.MintingAdmin)
      admins.length.should.equal(2)
    })

    it('add pending asset and enlist', async () => {
      const asset = {
        id: 1,
        valuation: 50,
        fingerprint: '0xabcd',
        tokens: 100,
      }

      let pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(0)

      const txId = await mpv.addAsset.call(asset, {
        from: defaultMintingAdmin
      })
      await mpv.addAsset(asset, {
        from: defaultMintingAdmin
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(1)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondAdmin,
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(0)
    })

    it('reset pending asset votes', async () => {
      const asset = {
        id: 11,
        valuation: 50,
        fingerprint: '0xabcd',
        tokens: 100,
      }

      const txId = await mpv.addAsset.call(asset, {
        from: defaultMintingAdmin
      })
      await mpv.addAsset(asset, {
        from: defaultMintingAdmin
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      let pendingAssetsCount = await mpv.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(1)

      const asset2 = {
        id: 12,
        valuation: 50,
        fingerprint: '0xabcd',
        tokens: 100,
      }

      await mpv.addAsset(asset2, {
        from: defaultMintingAdmin
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(2)

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondAdmin,
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(0)
    })

    it('get asset', async () => {
      const asset = await mpv.getAsset.call(1)
      asset.tokens.should.equal('100')
    })

    it('add multiple pending assets, remove pending asset', async () => {
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

      const txId = await mpv.addAssets.call(assets, {
        from: defaultMintingAdmin
      })
      await mpv.addAssets(assets, {
        from: defaultMintingAdmin
      })

      let pendingAssetsCount = await mpv.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(2)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      let confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(1)

      pendingAssetsCount = await mpv.pendingAssetsCount.call()
      pendingAssetsCount.toNumber().should.equal(2)

      const assetId = 2
      await mpv.removePendingAsset(assetId, {
        from: defaultMintingAdmin
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(1)

      confirmationCount = await mintingAdminMultiSig.getConfirmationCount.call(txId)
      confirmationCount.toNumber().should.equal(0)

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: defaultMintingAdmin,
      })

      await mintingAdminMultiSig.confirmTransaction(txId, {
        from: secondAdmin,
      })

      pendingAssetsCount = await mpv.pendingAssetsCount.call({
        from: accounts[0]
      })
      pendingAssetsCount.toNumber().should.equal(0)
    })
  })
})
