const { shouldFail } = require('openzeppelin-test-helpers')
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
const MULTIPLIER = 10 ** 4
const REDEMPTION_FEE = 0.1 * MULTIPLIER
const DAILY_LIMIT = 1000 * MULTIPLIER

contract('Assets', accounts => {
  let whitelist, masterPropertyValue // needed for token setup
  let assets, mpvToken, whitelistedAccts, basicOwnerMultiSig
  let redemptionFeeReceiverWallet, redemptionAdminMultiSig, redemptionAdminRole

  before(async () => {
    // Basic Setup for functioning MPVToken
    redemptionFeeReceiverWallet = accounts[4]
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    masterPropertyValue = await MasterPropertyValueMock.new()
    whitelistedAccts = [accounts[0], accounts[1], accounts[2]]
    whitelist = await initializeWhitelist(multiSig)
    await whitelist.addWhitelisted(redemptionFeeReceiverWallet)
    basicOwnerMultiSig = accounts[5]
  })

  beforeEach(async () => {
    redemptionAdminMultiSig = await AdministeredMultiSigWallet.new([accounts[0]], 1)
    redemptionAdminRole = await RedemptionAdminRole.new()
    mpvToken = await initializeToken()
    assets = await initializeAssets()
    redemptionAdminRole.initialize(redemptionAdminMultiSig.address, assets.address)
  })

  describe('setRedemptionFee()', () => {
    it('properly sets redemptionFee to the given value', async () => {
      (await assets.redemptionFee()).toNumber().should.equal(REDEMPTION_FEE)
      await assets.setRedemptionFee(500, {
        from: basicOwnerMultiSig
      })
      const newFee = (await assets.redemptionFee()).toNumber()
      newFee.should.equal(500)
    })
  })

  describe('setRedemptionFeeReceiverWallet()', () => {
    it('properly sets setRedemptionFeeReceiverWallet to the given value', async () => {
      const defaultAddr = await assets.redemptionFeeReceiverWallet()
      defaultAddr.should.equal(redemptionFeeReceiverWallet)
      await assets.setRedemptionFeeReceiverWallet(accounts[5], {
        from: basicOwnerMultiSig
      })
      const newAddr = await assets.redemptionFeeReceiverWallet()
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
        statusEvents: [],
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
        tokens: 100 * MULTIPLIER,
        status: 1,
        owner: accounts[0],
        timestamp: now,
        statusEvents: [],
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], 200 * MULTIPLIER)
      await mpvToken.approve(assets.address, 200 * MULTIPLIER, { from: accounts[0] })
    })

    it('sets the asset status to LOCKED', async () => {
      const enlisted = 1
      const locked = 2
      expect((await assets.assets(1)).status.toNumber()).to.equal(enlisted)
      await assets.requestRedemption(1, { from: accounts[0] })
      expect((await assets.assets(1)).status.toNumber()).to.equal(locked)
    })

    it('reverts if the account does not have the proper balance approved', async () => {
      await mintTokens(accounts[1], 100 * MULTIPLIER) // amount doesn't cover fee
      await mpvToken.approve(assets.address, 100 * MULTIPLIER, { from: accounts[1] })
      await shouldFail(assets.requestRedemption(1, { from: accounts[1] }))
    })

    it('reverts it the asset does not have the status ENLISTED', async () => {
      const invalidAsset = {
        id: 2,
        notarizationId: '0xabcd',
        tokens: 100 * MULTIPLIER,
        status: 0,
        owner: accounts[0],
        timestamp: moment().unix(),
        statusEvents: [],
      }

      await assets.add(invalidAsset)
      await shouldFail(assets.requestRedemption(2, { from: accounts[1] }))
    })

    it('transfers the fee and asset token value amount from the account', async () => {
      const totalCost = 1001000
      const previousAcctBalance = (await mpvToken.balanceOf(accounts[0])).toNumber()
      await assets.requestRedemption(1, { from: accounts[0] })
      const newAcctBalance = (await mpvToken.balanceOf(accounts[0])).toNumber()
      expect(previousAcctBalance - newAcctBalance).to.equal(totalCost)
    })

    it('locks the asset token value in assets contract under the account address', async () => {
      previousAssetsBalance = (await mpvToken.balanceOf(assets.address)).toNumber()
      previousLockedTokens = await assets.redemptionTokenLocks(1)

      await assets.requestRedemption(1, { from: accounts[0] })

      newAssetsBalance = (await mpvToken.balanceOf(assets.address)).toNumber()
      newLockedTokens = await assets.redemptionTokenLocks(1)

      expect(newAssetsBalance - previousAssetsBalance).to.equal(newAsset.tokens)
      expect(previousLockedTokens.amount.toNumber()).to.equal(0)
      expect(newLockedTokens.amount.toNumber()).to.equal(newAsset.tokens)
      expect(newLockedTokens.account).to.equal(accounts[0])
    })

    it('transfers the redemption fee to the redemptionFeeReceiverWallet', async () => {
      const fee = (await assets.redemptionFee()).toNumber()
      const previousTokenBalance = (await mpvToken.balanceOf(redemptionFeeReceiverWallet)).toNumber()

      await assets.requestRedemption(1, { from: accounts[0] })
      const newTokenBalance = (await mpvToken.balanceOf(redemptionFeeReceiverWallet)).toNumber()
      expect(newTokenBalance - previousTokenBalance).to.equal(fee)
    })

    it('adds the transaction to the redemptionMultiSig', async () => {
      expect((await redemptionAdminMultiSig.transactionCount()).toNumber()).to.equal(0)
      await assets.requestRedemption(1, { from: accounts[0] })
      expect((await redemptionAdminMultiSig.transactionCount()).toNumber()).to.equal(1)
    })

    it('triggers the burningCountdownStart', async () => {
      let txId = await assets.requestRedemption.call(1, { from: accounts[0] })
      await assets.requestRedemption(1, { from: accounts[0] })

      expect((await redemptionAdminRole.redemptionCountdowns(1)).toNumber()).to.equal(0)
      await redemptionAdminMultiSig.confirmTransaction(txId)
      const updatedCountdown = (await redemptionAdminRole.redemptionCountdowns(1)).toNumber()
      expect(updatedCountdown).to.be.closeTo(moment().unix() - 5, moment().unix() + 5)
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
        tokens: 100 * MULTIPLIER,
        status: 1,
        owner: accounts[0],
        timestamp:  now,
        statusEvents: [],
      }
      await assets.add(newAsset)
      await mintTokens(accounts[0], 200 * MULTIPLIER)
      await mpvToken.approve(assets.address, 200 * MULTIPLIER, {from: accounts[0]})
      await assets.requestRedemption(1, {from: accounts[0]})
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

      const previousAssetsBalance = (await mpvToken.balanceOf(assets.address)).toNumber()
      const previousAcctBalance = (await mpvToken.balanceOf(redeemer)).toNumber()

      await assets.cancelRedemption(1)

      const currentAssetsBalance = (await mpvToken.balanceOf(assets.address)).toNumber()
      const currentAcctBalance = (await mpvToken.balanceOf(redeemer)).toNumber()

      expect(previousAssetsBalance - currentAssetsBalance).to.equal(refund)
      expect(currentAcctBalance - previousAcctBalance).to.equal(refund)
    })

    it('deletes the redemptionTokenLock info', async () => {
      let redemptionTokenLock = await assets.redemptionTokenLocks(1)
      expect(redemptionTokenLock.account).to.equal(redeemer)
      expect(redemptionTokenLock.amount.toNumber()).to.equal(newAsset.tokens)

      await assets.cancelRedemption(1)

      redemptionTokenLock = await assets.redemptionTokenLocks(1)

      expect(redemptionTokenLock.account).to.equal(ZERO_ADDR)
      expect(redemptionTokenLock.amount.toNumber()).to.equal(0)
    })

    it('reverts if the asset status it not LOCKED', async () => {
      enlistedAsset = {
        id: 2,
        notarizationId: '0xabcd',
        tokens: 100 * MULTIPLIER,
        status: 1,
        owner: accounts[0],
        timestamp:  moment().unix(),
        statusEvents: [],
      }

      await assets.add(enlistedAsset)
      await shouldFail(assets.cancelRedemption(2))
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
      4,
      whitelist.address,
      masterPropertyValue.address,
      DAILY_LIMIT
    )
    return mpvToken
  }

  async function initializeAssets () {
    const assets = await Assets.new()
    await assets.initialize(
      REDEMPTION_FEE,
      redemptionFeeReceiverWallet,
      redemptionAdminRole.address,
      redemptionAdminMultiSig.address,
      basicOwnerMultiSig,
      mpvToken.address

    )
    await whitelist.addWhitelisted(assets.address)
    return assets
  }

  async function initializeWhitelist (multiSig) {
    const whitelist = await Whitelist.new()
    await whitelist.initialize(multiSig.address, accounts[5])
    for (acct of whitelistedAccts) {
      await whitelist.addWhitelisted(acct)
    }
    return whitelist
  }
})
