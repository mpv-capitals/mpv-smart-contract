const { shouldFail, time } = require('openzeppelin-test-helpers')
const { mine } = require('./helpers')
require('chai').should()
const moment = require('moment')

const MPVToken = artifacts.require('MPVToken')
const Whitelist = artifacts.require('Whitelist')
const MasterPropertyValueMock = artifacts.require('MasterPropertyValueMock')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')
const BasicOwnerMultiSigWalletMock = artifacts.require('BasicOwnerMultiSigWalletMock')

const MULTIPLIER = 10 ** 4

contract('MPVToken', accounts => {
  let token, whitelist, masterPropertyValue

  beforeEach(async () => {
    masterPropertyValue = await MasterPropertyValueMock.new()
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    const basicOwnerMultiSig = await BasicOwnerMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    whitelist = await Whitelist.new()
    await whitelist.initialize(
      multiSig.address,
      basicOwnerMultiSig.address,
      masterPropertyValue.address
    )
    token = await MPVToken.new()
    const dailyLimit = 1000 * (10 ** 4) // wei value given token.decimal = 4
    await token.initialize(
      'Master Property Value',
      'MPV',
      4,
      whitelist.address,
      masterPropertyValue.address,
      masterPropertyValue.address, // mintingAdmin
      masterPropertyValue.address // redemptionAdmin
    )

    await whitelist.addWhitelisted(accounts[0])
    await whitelist.addWhitelisted(accounts[1])
    await whitelist.addWhitelisted(accounts[2])
  })

  describe('transfer()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 10000 * MULTIPLIER)
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
    })

    it('sends tokens to whitelisted addresses', async () => {
      (await token.transfer.call(accounts[1], 30)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transfer(accounts[3], 30))
    })

    it('reverts if MasterPropertyValue is paused', async () => {
      await masterPropertyValue.mock_setPaused(true)
      await shouldFail(token.transfer(accounts[1], 30))
    })

    it('reverts if transfer breaches daily limit', async () => {
      await token.updateDailyLimit(1000 * MULTIPLIER)
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], 500 * MULTIPLIER)
      await shouldFail(token.transfer(accounts[1], 501 * MULTIPLIER))
    })
  })

  describe('transferFrom()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 10000 * MULTIPLIER)
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
      await token.approve(accounts[0], 10000 * MULTIPLIER, { from: accounts[1] })
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
    })

    it('sends tokens to whitelisted addresses', async () => {
      (await token.transferFrom.call(accounts[1], accounts[2], 20)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transferFrom.call(accounts[1], accounts[3], 20))
    })

    it('reverts if MasterPropertyValue is paused', async () => {
      await masterPropertyValue.mock_setPaused(true)
      await shouldFail(token.transferFrom.call(accounts[1], accounts[2], 20))
    })

    it('reverts if transfer breaches daily limit', async () => {
      await token.updateDailyLimit(1000 * MULTIPLIER, { from: accounts[1] })
      await mine(60 * 60 * 48 + 1)
      await token.transferFrom(accounts[1], accounts[0], 500 * MULTIPLIER)
      await shouldFail(token.transferFrom(accounts[1], accounts[0], 501 * MULTIPLIER))
    })
  })

  describe('delayedTransfer()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 10000 * MULTIPLIER)
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
      await token.updateDailyLimit(50 * MULTIPLIER)
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], 20 * MULTIPLIER)
    })

    it('creates a DelayedTransfer structure with the correct values', async () => {
      const largeTransferAmt = 60 * MULTIPLIER
      const txId = await token.delayedTransfer.call(accounts[1], largeTransferAmt)
      await token.delayedTransfer(accounts[1], largeTransferAmt)
      const delayedTransfer = await token.delayedTransfers(txId)

      expect(delayedTransfer.from).to.equal(accounts[0])
      expect(delayedTransfer.to).to.equal(accounts[1])
      expect(delayedTransfer.value.toNumber()).to.equal(largeTransferAmt)
      expect(delayedTransfer.transferMethod.toNumber()).to.equal(0)
      expect(delayedTransfer.countdownStart.toNumber())
        .to.be.closeTo((await time.latest()).toNumber(), 1)
    })
  })

  describe('delayedTransferFrom()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 10000 * MULTIPLIER)
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
      await token.updateDailyLimit(50 * MULTIPLIER)
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], 20 * MULTIPLIER)
    })

    it('creates a DelayedTransfer structure with the correct values', async () => {
      const largeTransferAmt = 70 * MULTIPLIER
      const txId = await token.delayedTransferFrom.call(accounts[0], accounts[1], largeTransferAmt)
      await token.delayedTransferFrom(accounts[0], accounts[1], largeTransferAmt)
      const delayedTransfer = await token.delayedTransfers(txId)

      expect(delayedTransfer.from).to.equal(accounts[0])
      expect(delayedTransfer.to).to.equal(accounts[1])
      expect(delayedTransfer.value.toNumber()).to.equal(largeTransferAmt)
      expect(delayedTransfer.transferMethod.toNumber()).to.equal(1)
      expect(delayedTransfer.countdownStart.toNumber())
        .to.be.closeTo((await time.latest()).toNumber(), 1)
    })
  })

  describe('mint()', () => {
    it('mints new tokens if called by masterPropertyValue', async () => {
      const mintAmount = 500
      const previousTokenSupply = (await token.totalSupply()).toNumber()

      await masterPropertyValue.mock_callMint(token.address, accounts[0], mintAmount)

      const newTokenSupply = (await token.totalSupply()).toNumber()
      newTokenSupply.should.equal(previousTokenSupply + mintAmount)
    })

    it('reverts if called by address other than the mintingAdmin', async () => {
      await shouldFail(token.mint(accounts[0], 500, { from: accounts[0] }))
    })

    it('reverts if minting tokens to a non-whitelisted address', async () => {
      await shouldFail(masterPropertyValue.mock_callMint(token.address, accounts[4], 500))
    })
  })

  describe('burn()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 500)
    })

    it('burns tokens if called by redemptionAdmin', async () => {
      const burnAmount = 300
      const previousTokenSupply = (await token.totalSupply()).toNumber()

      await masterPropertyValue.mock_callBurn(token.address, accounts[0], burnAmount)

      const newTokenSupply = (await token.totalSupply()).toNumber()
      newTokenSupply.should.equal(previousTokenSupply - burnAmount)
    })

    it('reverts if called by address other than the redemptionAdmin', async () => {
      await shouldFail(token.burn(accounts[0], 300, { from: accounts[0] }))
    })
  })

  describe('detectTransferRestriction()', () => {
    beforeEach(async () => {
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 10000 * MULTIPLIER)
      await masterPropertyValue.mock_callMint(token.address, accounts[1], 10000 * MULTIPLIER)
    })

    describe('regarding whitelisted accounts', () => {
      let whitelistedAcct, nonWhitelistedAcct

      before(async () => {
        whitelistedAcct = accounts[1]
        nonWhitelistedAcct = accounts[5]
      })

      it('returns 0 if sending to a whitelisted account', async () => {
        expect(
          (await token.detectTransferRestriction(
            accounts[0], whitelistedAcct,
            11 * MULTIPLIER)).toNumber()
          ).to.equal(0)
      })

      it('returns 1 if sending to a nonwhitelisted account', async () => {
        expect(
          (await token.detectTransferRestriction(
            accounts[0], nonWhitelistedAcct,
            11 * MULTIPLIER)).toNumber()
          ).to.equal(1)
      })
    })

    describe('regarding daily limits', () => {
      let dailyLimit

      before(async () => {
        dailyLimit = 50 * MULTIPLIER
      })

      it('returns 0 if there is no daily limit', async () => {
        await token.transfer(accounts[1], 40 * MULTIPLIER)
        expect(
          (await token.detectTransferRestriction(
            accounts[0], accounts[1],
            11 * MULTIPLIER)).toNumber()
          ).to.equal(0)
      })

      describe('when new daily limit', () => {
        beforeEach(async () => {
          await token.updateDailyLimit(dailyLimit)
          await mine(60 * 60 * 48 + 1)
          await token.transfer(accounts[1], 40 * MULTIPLIER)
          await mine(60 * 60 * 24 + 1)
        })

        it('returns 0 if transfer limit does not exceed daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              11 * MULTIPLIER)).toNumber()
            ).to.equal(0)
        })

        it('returns 2 if transfer value exceeds daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              51 * MULTIPLIER)).toNumber()
            ).to.equal(2)
        })
      })

      describe('when still in previous daily limit period', () => {
        beforeEach(async () => {
          await token.updateDailyLimit(dailyLimit)
          await mine(60 * 60 * 48 + 1)
          await token.transfer(accounts[1], 40 * MULTIPLIER)
        })

        it('returns 0 if value + previous transfers does not exceed daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              10 * MULTIPLIER)).toNumber()
            ).to.equal(0)
        })

        it('returns 2 if value + previous transfers exceeds daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              11 * MULTIPLIER)).toNumber()
            ).to.equal(2)
        })
      })
    })
  })

  describe('messageForTransferRestriction()', () => {
    let validTransferMsg, dailyLimitMsg, invalidCodeMsg, whitelistMsg

    before(async () => {
      validTransferMsg = 'Valid transfer'
      whitelistMsg     = 'Invalid transfer: nonwhitelisted recipient'
      dailyLimitMsg    = 'Invalid transfer: exceeds daily limit'
      invalidCodeMsg   = 'Invalid restrictionCode'
    })

    it('returns the correct message for input 0', async () => {
      expect(await token.messageForTransferRestriction(0)).to.equal(validTransferMsg)
    })

    it('returns the correct message for input 1', async () => {
      expect(await token.messageForTransferRestriction(1)).to.equal(whitelistMsg)
    })

    it('returns the correct message for input 2', async () => {
      expect(await token.messageForTransferRestriction(2)).to.equal(dailyLimitMsg)
    })

    it('reverts for input above 2', async () => {
      await shouldFail(token.messageForTransferRestriction(3))
    })
  })
})
