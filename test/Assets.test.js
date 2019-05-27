const { shouldFail } = require('openzeppelin-test-helpers')
const { mine } = require('./helpers')
require('chai').should()
const moment = require('moment')

const MPVToken = artifacts.require('MPVToken')
const Assets = artifacts.require('Assets')
const Whitelist = artifacts.require('Whitelist')
const MasterPropertyValueMock = artifacts.require('MasterPropertyValueMock')
const AdministeredMultiSigWallet = artifacts.require('AdministeredMultiSigWallet')
const RedemptionAdminRole = artifacts.require('RedemptionAdminRole')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')

const ZERO_ADDR = '0x0000000000000000000000000000000000000000'
const BN = n => new web3.utils.BN(n)
const MULTIPLIER = BN(10).pow(BN(18))
const REDEMPTION_FEE = MULTIPLIER.div(BN(10)) // 0.1

contract('Assets', accounts => {
  let whitelist, masterPropertyValue // needed for token setup
  let assets, mpvToken, whitelistedAccts, basicProtectorMultiSig
  let redemptionFeeReceiverWallet, redemptionAdminMultiSig, redemptionAdminRole

  before(async () => {
    // Basic Setup for functioning MPVToken
    redemptionFeeReceiverWallet = accounts[4]
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    masterPropertyValue = await MasterPropertyValueMock.new()
    whitelistedAccts = [accounts[0], accounts[1], accounts[2]]
    whitelist = await initializeWhitelist(multiSig)
    await whitelist.addWhitelisted(redemptionFeeReceiverWallet)
    basicProtectorMultiSig = await AdministeredMultiSigWallet.new()
    await basicProtectorMultiSig.initialize([accounts[0]], 1)
  })

  beforeEach(async () => {
    // Setup redemptionAdminRole
    redemptionAdminMultiSig = await AdministeredMultiSigWallet.new()
    redemptionAdminMultiSig.initialize([accounts[0]], 1)
    redemptionAdminRole = await RedemptionAdminRole.new()

    // Initialize token, assets, and redemptionAdminRole
    mpvToken = await initializeToken()
    assets = await initializeAssets(basicProtectorMultiSig.address)
    redemptionAdminRole.initialize(
      redemptionAdminMultiSig.address,
      basicProtectorMultiSig.address,
      accounts[5], // superProtectorMultiSig
      assets.address,
      mpvToken.address,
      masterPropertyValue.address
    )
    await redemptionAdminMultiSig.updateTransactor(assets.address)
  })

  describe('updateRedemptionFee()', () => {
    it('properly sets redemptionFee to the given value', async () => {
      // initialize assets contract with accessible basicProtectorMultSig for testing
      const multiSig = accounts[1]
      const assetsB = await initializeAssets(multiSig)
      expect((await assetsB.redemptionFee()).toString()).to.equal(REDEMPTION_FEE.toString())
      await assetsB.updateRedemptionFee(500, { from: multiSig })
      const newFee = (await assetsB.redemptionFee()).toNumber()
      newFee.should.equal(500)
    })
  })

  describe('updateRedemptionFeeReceiverWallet()', () => {
    it('properly sets setRedemptionFeeReceiverWallet to the given value', async () => {
      // initialize assets contract with accessible basicProtectorMultSig for testing
      const multiSig = accounts[1]
      const assetsB = await initializeAssets(multiSig)
      const defaultAddr = await assetsB.redemptionFeeReceiverWallet()
      defaultAddr.should.equal(redemptionFeeReceiverWallet)
      await assetsB.updateRedemptionFeeReceiverWallet(accounts[5], {
        from: multiSig,
      })
      const newAddr = await assetsB.redemptionFeeReceiverWallet()
      newAddr.should.equal(accounts[5])
    })
  })

  describe('add()', () => {
    it('adds the proper asset to the assets mapping', async () => {
      const now = moment().unix()
      const newAsset = {
        id: 5,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: now,
      }

      expect((await assets.assets(5)).id.toNumber()).to.equal(0)
      await assets.add(newAsset)
      const savedAsset = await assets.assets(5)
      expect(savedAsset.id.toNumber()).to.equal(5)
      expect(savedAsset.notarizationId.slice(0, 6)).to.equal(newAsset.notarizationId)
      expect(savedAsset.tokens.toNumber()).to.equal(newAsset.tokens)
      expect(savedAsset.owner).to.equal(newAsset.owner)
      expect(savedAsset.status.toNumber()).to.equal(newAsset.status)
      // expect(savedAsset.status.toNumber()).to.equal(newAsset.timestamp) //broken???
    })
  })

  describe('requestRedemption()', () => {
    let newAsset
    beforeEach(async () => {
      const now = moment().unix()
      newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], BN(200).mul(MULTIPLIER).toString())
      await mpvToken.approve(assets.address, (200 * MULTIPLIER).toString(), { from: accounts[0] })
    })

    it('sets the asset status to LOCKED', async () => {
      const enlisted = 1
      const locked = 2
      expect((await assets.assets(1)).status.toNumber()).to.equal(enlisted)
      await assets.requestRedemption(1, { from: accounts[0] })
      expect((await assets.assets(1)).status.toNumber()).to.equal(locked)
    })

    it('reverts if the account does not have the proper balance approved', async () => {
      await mintTokens(accounts[1], BN(100).mul(MULTIPLIER).toString()) // amount doesn't cover fee
      await mpvToken.approve(assets.address, BN(100).mul(MULTIPLIER).toString(), { from: accounts[1] })
      await shouldFail(assets.requestRedemption(1, { from: accounts[1] }))
    })

    it('reverts it the asset does not have the status ENLISTED', async () => {
      const invalidAsset = {
        id: 2,
        notarizationId: '0xabcd',
        tokens: (100 * MULTIPLIER).toString(),
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      await assets.add(invalidAsset)
      await shouldFail(assets.requestRedemption(2, { from: accounts[1] }))
    })

    it('transfers the fee and asset token value amount from the account', async () => {
      const totalCost = REDEMPTION_FEE.add(BN(100).mul(MULTIPLIER))
      const previousAcctBalance = (await mpvToken.balanceOf(accounts[0]))
      await assets.requestRedemption(1, { from: accounts[0] })
      const newAcctBalance = (await mpvToken.balanceOf(accounts[0]))
      expect(previousAcctBalance.sub(newAcctBalance).toString()).to.equal(totalCost.toString())
    })

    it('locks the asset token value in assets contract under the account address', async () => {
      const previousAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const previousLockedTokens = await assets.redemptionTokenLocks(1)

      await assets.requestRedemption(1, { from: accounts[0] })

      const newAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const newLockedTokens = await assets.redemptionTokenLocks(1)

      expect(newAssetsBalance.sub(previousAssetsBalance).toString()).to.equal(newAsset.tokens.toString())
      expect(previousLockedTokens.amount.toNumber()).to.equal(0)
      expect(newLockedTokens.amount.toString()).to.equal(newAsset.tokens)
      expect(newLockedTokens.account).to.equal(accounts[0])
    })

    it('transfers the redemption fee to the redemptionFeeReceiverWallet', async () => {
      const fee = (await assets.redemptionFee())
      const previousTokenBalance = (await mpvToken.balanceOf(redemptionFeeReceiverWallet))

      await assets.requestRedemption(1, { from: accounts[0] })
      const newTokenBalance = (await mpvToken.balanceOf(redemptionFeeReceiverWallet))
      expect(newTokenBalance.sub(previousTokenBalance).toString()).to.equal(fee.toString())
    })

    it('adds the transaction to the redemptionMultiSig', async () => {
      expect((await redemptionAdminMultiSig.transactionCount()).toNumber()).to.equal(0)
      await assets.requestRedemption(1, { from: accounts[0] })
      expect((await redemptionAdminMultiSig.transactionCount()).toNumber()).to.equal(1)
    })

    it('triggers the burningCountdownStart', async () => {
      const txId = await assets.requestRedemption.call(1, { from: accounts[0] })
      await assets.requestRedemption(1, { from: accounts[0] })

      expect((await redemptionAdminRole.redemptionCountdowns(1)).toNumber()).to.equal(0)
      await redemptionAdminMultiSig.confirmTransaction(txId)
      const updatedCountdown = (await redemptionAdminRole.redemptionCountdowns(1)).toNumber()
      expect(updatedCountdown).to.be.closeTo(moment().unix() - 5, moment().unix() + 5)
    })
  })

  describe('requestRedemptions()', () => {
    let newAssets
    beforeEach(async () => {
      const now = moment().unix()
      newAssets = [{
        id: 6,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }, {
        id: 7,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }]
      await assets.addList(newAssets)
      await mintTokens(accounts[0], BN(400).mul(MULTIPLIER).toString())
      await mpvToken.approve(assets.address, BN(400).mul(MULTIPLIER).toString(), { from: accounts[0] })
    })

    it('sets the assets\' status to LOCKED', async () => {
      const enlisted = 1
      const locked = 2
      expect((await assets.assets(6)).status.toNumber()).to.equal(enlisted)
      expect((await assets.assets(7)).status.toNumber()).to.equal(enlisted)
      await assets.requestRedemption(6, { from: accounts[0] })
      await assets.requestRedemption(7, { from: accounts[0] })
      expect((await assets.assets(6)).status.toNumber()).to.equal(locked)
      expect((await assets.assets(7)).status.toNumber()).to.equal(locked)
    })
  })

  describe('cancelRedemption()', () => {
    let newAsset, redeemer
    beforeEach(async () => {
      const now = moment().unix()
      redeemer = accounts[0]
      newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], BN(200).mul(MULTIPLIER).toString())
      await mpvToken.approve(assets.address, BN(200).mul(MULTIPLIER).toString(), { from: accounts[0] })
      await assets.requestRedemption(1, { from: accounts[0] })
    })

    it('sets the asset status back to ENLISTED', async () => {
      const locked = 2
      const enlisted = 1
      expect((await assets.assets(1)).status.toNumber()).to.equal(locked)
      await assets.cancelRedemption(1)
      expect((await assets.assets(1)).status.toNumber()).to.equal(enlisted)
    })

    it('transfers the redemption token amount back to the requesting account', async () => {
      const refund = newAsset.tokens

      const previousAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const previousAcctBalance = (await mpvToken.balanceOf(redeemer))

      await assets.cancelRedemption(1)

      const currentAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const currentAcctBalance = (await mpvToken.balanceOf(redeemer))

      expect(previousAssetsBalance.sub(currentAssetsBalance).toString()).to.equal(refund)
      expect(currentAcctBalance.sub(previousAcctBalance).toString()).to.equal(refund)
    })

    it('deletes the redemptionTokenLock info', async () => {
      let redemptionTokenLock = await assets.redemptionTokenLocks(1)
      expect(redemptionTokenLock.account).to.equal(redeemer)
      expect(redemptionTokenLock.amount.toString()).to.equal(newAsset.tokens)

      await assets.cancelRedemption(1)

      redemptionTokenLock = await assets.redemptionTokenLocks(1)

      expect(redemptionTokenLock.account).to.equal(ZERO_ADDR)
      expect(redemptionTokenLock.amount.toNumber()).to.equal(0)
    })

    it('reverts if the asset status it not LOCKED', async () => {
      const enlistedAsset = {
        id: 2,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      await assets.add(enlistedAsset)
      await shouldFail(assets.cancelRedemption(2))
    })
  })

  describe('rejectRedemption()', () => {
    let newAsset, redeemer
    beforeEach(async () => {
      const now = moment().unix()
      redeemer = accounts[0]
      newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], BN(200).mul(MULTIPLIER).toString())
      await mpvToken.approve(assets.address, BN(200).mul(MULTIPLIER).toString(), { from: accounts[0] })
      await assets.requestRedemption(1, { from: accounts[0] })
    })

    it('sets the asset status back to ENLISTED', async () => {
      const locked = 2
      const enlisted = 1
      expect((await assets.assets(1)).status.toNumber()).to.equal(locked)
      await redemptionAdminRole.rejectRedemption(1)
      expect((await assets.assets(1)).status.toNumber()).to.equal(enlisted)
    })

    it('transfers the redemption token amount back to the requesting account', async () => {
      const refund = newAsset.tokens

      const previousAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const previousAcctBalance = (await mpvToken.balanceOf(redeemer))

      await redemptionAdminRole.rejectRedemption(1)

      const currentAssetsBalance = (await mpvToken.balanceOf(assets.address))
      const currentAcctBalance = (await mpvToken.balanceOf(redeemer))

      expect(previousAssetsBalance.sub(currentAssetsBalance).toString()).to.equal(refund)
      expect(currentAcctBalance.sub(previousAcctBalance).toString()).to.equal(refund)
    })

    it('deletes the redemptionTokenLock info', async () => {
      let redemptionTokenLock = await assets.redemptionTokenLocks(1)
      expect(redemptionTokenLock.account).to.equal(redeemer)
      expect(redemptionTokenLock.amount.toString()).to.equal(newAsset.tokens)

      await redemptionAdminRole.rejectRedemption(1)

      redemptionTokenLock = await assets.redemptionTokenLocks(1)

      expect(redemptionTokenLock.account).to.equal(ZERO_ADDR)
      expect(redemptionTokenLock.amount.toNumber()).to.equal(0)
    })

    it('reverts if the asset status it not LOCKED', async () => {
      const enlistedAsset = {
        id: 2,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: moment().unix(),
      }

      await assets.add(enlistedAsset)
      await shouldFail(redemptionAdminRole.rejectRedemption(2))
    })

    it('reverts if called by address other than redemptionAdminRole', async () => {
      await shouldFail(assets.rejectRedemption(1))
    })
  })

  describe('executeRedemption()', () => {
    beforeEach(async () => {
      const now = moment().unix()
      const newAsset = {
        id: 1,
        notarizationId: '0xabcd',
        tokens: BN(100).mul(MULTIPLIER).toString(),
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], BN(200).mul(MULTIPLIER).toString())
      await mpvToken.approve(assets.address, BN(200).mul(MULTIPLIER).toString(), { from: accounts[0] })
      await assets.requestRedemption(1, { from: accounts[0] })
      await redemptionAdminMultiSig.confirmTransaction(0)
      mine(60 * 60 * 48 + 1)
    })

    it('sets asset status to Redeemed', async () => {
      const locked = 2
      const redeemed = 3

      expect((await assets.assets(1)).status.toNumber()).to.equal(locked)
      await redemptionAdminRole.executeRedemption(1)
      expect((await assets.assets(1)).status.toNumber()).to.equal(redeemed)
    })

    it('deletes the corresponding redemptionTokenLocks data', async () => {
      expect((await assets.redemptionTokenLocks(1)).account).to.equal(accounts[0])
      await redemptionAdminRole.executeRedemption(1)
      expect((await assets.redemptionTokenLocks(1)).account).to.equal(ZERO_ADDR)
    })

    it('reverts if called by address other than redemptionAdminRole', async () => {
      await shouldFail(assets.executeRedemption(1))
    })
  })

  describe('statusTotalTokens()', () => {
    it('returns total minted for PENDING assets', async () => {
      const now = moment().unix()
      const newAsset = {
        id: 10,
        notarizationId: '0xabcd',
        tokens: 100,
        status: 0,
        owner: accounts[0],
        timestamp: now,
      }

      await assets.addPendingAsset(newAsset)
      let statusTotalTokens = await assets.statusTotalTokens.call(0)
      expect(statusTotalTokens.toNumber()).to.equal(100)

      await assets.removePendingAsset(newAsset.id)
      statusTotalTokens = await assets.statusTotalTokens.call(0)
      expect(statusTotalTokens.toNumber()).to.equal(0)
    })

    it('returns total minted for ENLISTED assets', async () => {
      const now = moment().unix()
      const newAssets = [{
        id: 11,
        notarizationId: '0xabcd',
        tokens: 105,
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }, {
        id: 12,
        notarizationId: '0xabcd',
        tokens: 95,
        status: 1,
        owner: accounts[0],
        timestamp: now,
      }]

      await assets.addList(newAssets)
      const statusTotalTokens = await assets.statusTotalTokens.call(1)
      expect(statusTotalTokens.toNumber()).to.equal(200)
    })
  })

  async function mintTokens (account, amount) {
    await masterPropertyValue.mock_callMint(mpvToken.address, account, amount)
  }

  async function initializeToken () {
    const mpvToken = await MPVToken.new()
    await mpvToken.initialize(
      'Master Property Value',
      'MPV',
      18,
      whitelist.address,
      masterPropertyValue.address,
      masterPropertyValue.address, // mintingAdmin
      redemptionAdminRole.address, // redemptionAdmin
      accounts[5] // superProtectorMultiSig
    )
    return mpvToken
  }

  async function initializeAssets (basicProtectorMultiSig) {
    const assets = await Assets.new()
    await assets.initialize(
      REDEMPTION_FEE.toString(),
      redemptionFeeReceiverWallet,
      accounts[0], // mintingAdminRole
      redemptionAdminRole.address,
      redemptionAdminMultiSig.address,
      basicProtectorMultiSig,
      mpvToken.address,
      masterPropertyValue.address
    )
    await whitelist.addWhitelisted(assets.address)
    return assets
  }

  async function initializeWhitelist (multiSig) {
    const whitelist = await Whitelist.new()
    await whitelist.initialize(
      multiSig.address,
      accounts[5],
      masterPropertyValue.address
    )
    for (const acct of whitelistedAccts) {
      await whitelist.addWhitelisted(acct)
    }
    return whitelist
  }
})
