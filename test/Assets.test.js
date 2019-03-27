const { shouldFail } = require('openzeppelin-test-helpers')
require('chai').should()
const moment = require('moment')

const MPVToken = artifacts.require('MPVToken')
const Assets = artifacts.require('Assets')
const Whitelist = artifacts.require('Whitelist')
const MasterPropertyValueMock = artifacts.require('MasterPropertyValueMock')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')

const ZERO_ADDR = '0x0000000000000000000000000000000000000000'
const MULTIPLIER = 10 ** 4
const REDEMPTION_FEE = 0.1 * MULTIPLIER
const DAILY_LIMIT = 1000 * MULTIPLIER


contract('Assets', accounts => {
  let whitelist, masterPropertyValue // needed for token setup
  let assets, mpvToken, whitelistedAccts, redemptionFeeReceiverWallet

  before(async () => {
    // Basic Setup for functioning MPVToken
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    masterPropertyValue = await MasterPropertyValueMock.new()
    whitelistedAccts = [accounts[0], accounts[1], accounts[2]]
    whitelist = await initializeWhitelist(multiSig)
  })

  beforeEach(async () => {
    redemptionFeeReceiverWallet = accounts[4]
    mpvToken = await initializeToken()
    assets = await initializeAssets()
  })

  describe('setRedemptionFee()', () => {
    it('properly sets redemptionFee to the given value', async () => {
      (await assets.redemptionFee()).toNumber().should.equal(REDEMPTION_FEE)
      await assets.setRedemptionFee(500)
      const newFee = (await assets.redemptionFee()).toNumber()
      newFee.should.equal(500)
    })
  })

  describe('setRedemptionFeeReceiverWallet()', () => {
    it('properly sets setRedemptionFeeReceiverWallet to the given value', async () => {
      const defaultAddr = await assets.redemptionFeeReceiverWallet()
      defaultAddr.should.equal(redemptionFeeReceiverWallet)
      await assets.setRedemptionFeeReceiverWallet(accounts[5])
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
        timestamp:  now,
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

  async function initializeToken() {
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

  async function initializeAssets() {
    const assets = await Assets.new()
    await assets.initialize(REDEMPTION_FEE, redemptionFeeReceiverWallet)
    return assets
  }

  async function initializeWhitelist(multiSig) {
    const whitelist = await Whitelist.new()
    await whitelist.initialize(multiSig.address, accounts[5])
    for (acct of whitelistedAccts) {
      await whitelist.addWhitelisted(acct)
    }
    return whitelist
  }
})
