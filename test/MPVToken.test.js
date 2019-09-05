const { shouldFail, time } = require('openzeppelin-test-helpers')
const { mine } = require('./helpers')
require('chai').should()

const MPVToken = artifacts.require('MPVToken')
const Whitelist = artifacts.require('Whitelist')
const AssetsMock = artifacts.require('AssetsMock')
const MasterPropertyValueMock = artifacts.require('MasterPropertyValueMock')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')
const BasicProtectorMultiSigWalletMock = artifacts.require('BasicProtectorMultiSigWalletMock')

const ZERO_ADDR = '0x0000000000000000000000000000000000000000'
const BN = n => new web3.utils.BN(n)
const MULTIPLIER = BN(10).pow(BN(18))

contract.only('MPVToken', accounts => {
  let token, whitelist, masterPropertyValue, superProtectorMultiSig, assetsMock

  beforeEach(async () => {
    superProtectorMultiSig = accounts[5]
    masterPropertyValue = await MasterPropertyValueMock.new()
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    const basicProtectorMultiSig = await BasicProtectorMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    whitelist = await Whitelist.new()
    await whitelist.initialize(
      multiSig.address,
      basicProtectorMultiSig.address,
      masterPropertyValue.address
    )
    token = await MPVToken.new({
      gas: 6712383,
    })
    assetsMock = await AssetsMock.new()
    await token.initialize(
      'Master Property Value',
      'MPV',
      18,
      whitelist.address,
      masterPropertyValue.address,
      masterPropertyValue.address, // mintingAdmin
      masterPropertyValue.address, // redemptionAdmin
      superProtectorMultiSig
    )

    await token.updateAssets(assetsMock.address, {
      from: superProtectorMultiSig
    })
    await whitelist.addWhitelisted(accounts[0])
    await whitelist.addWhitelisted(accounts[1])
    await whitelist.addWhitelisted(accounts[2])
  })

  describe('transfer()', () => {
    beforeEach(async () => {
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], (BN(10000).mul(MULTIPLIER)).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], (BN(10000).mul(MULTIPLIER)).toString())
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
      await token.updateDailyLimit((BN(1000).mul(MULTIPLIER)).toString())
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], BN(500).mul(MULTIPLIER).toString())
      await shouldFail(token.transfer(accounts[1], BN(501).mul(MULTIPLIER).toString()))
    })
  })

  describe('transferFrom()', () => {
    beforeEach(async () => {
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], BN(10000).mul(MULTIPLIER))
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER))
      await token.approve(accounts[0], BN(10000).mul(MULTIPLIER), { from: accounts[1] })
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER))
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
      await token.updateDailyLimit(BN(1000).mul(MULTIPLIER), { from: accounts[1] })
      await mine(60 * 60 * 48 + 1)
      await token.transferFrom(accounts[1], accounts[0], BN(500).mul(MULTIPLIER))
      await shouldFail(token.transferFrom(accounts[1], accounts[0], BN(501).mul(MULTIPLIER)))
    })
  })

  describe('delayedTransfer()', () => {
    let largeTransferAmt

    beforeEach(async () => {
      largeTransferAmt = BN(70).mul(MULTIPLIER)
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER).toString())
      await token.updateDailyLimit(BN(50).mul(MULTIPLIER).toString())
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], BN(20).mul(MULTIPLIER).toString())
    })

    it('creates a DelayedTransfer structure with the correct values', async () => {
      const largeTransferAmt = BN(60).mul(MULTIPLIER)
      const txId = await token.delayedTransfer.call(accounts[1], largeTransferAmt.toString())
      await token.delayedTransfer(accounts[1], largeTransferAmt)
      const delayedTransfer = await token.delayedTransfers(txId)

      expect(delayedTransfer.from).to.equal(accounts[0])
      expect(delayedTransfer.to).to.equal(accounts[1])
      expect(delayedTransfer.value.toString()).to.equal(largeTransferAmt.toString())
      expect(delayedTransfer.transferMethod.toNumber()).to.equal(0)
      expect(delayedTransfer.countdownStart.toNumber())
        .to.be.closeTo((await time.latest()).toNumber(), 1)
    })

    it('emits a DelayedTransferInitiated event', async () => {
      const { logs } = await token.delayedTransfer(accounts[1], largeTransferAmt.toString())
      expect(logs[0].event).to.equal('DelayedTransferInitiated')
    })
  })

  describe('delayedTransferFrom()', () => {
    let largeTransferAmt

    beforeEach(async () => {
      largeTransferAmt = BN(70).mul(MULTIPLIER)
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[2], BN(10000).mul(MULTIPLIER).toString())
      await token.updateDailyLimit(BN(50).mul(MULTIPLIER).toString())
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], BN(20).mul(MULTIPLIER).toString(), { from: accounts[2] })
    })

    it('creates a DelayedTransfer structure with the correct values', async () => {
      const txId = await token.delayedTransferFrom.call(accounts[0], accounts[1], largeTransferAmt)
      await token.delayedTransferFrom(accounts[0], accounts[1], largeTransferAmt)
      const delayedTransfer = await token.delayedTransfers(txId)

      expect(delayedTransfer.from).to.equal(accounts[0])
      expect(delayedTransfer.to).to.equal(accounts[1])
      expect(delayedTransfer.value.toString()).to.equal(largeTransferAmt.toString())
      expect(delayedTransfer.transferMethod.toNumber()).to.equal(1)
      expect(delayedTransfer.countdownStart.toNumber())
        .to.be.closeTo((await time.latest()).toNumber(), 1)
    })

    it('emits a DelayedTransferInitiated event', async () => {
      const { logs } = await token.delayedTransferFrom(accounts[0], accounts[1], largeTransferAmt.toString())
      expect(logs[0].event).to.equal('DelayedTransferInitiated')
    })
  })

  describe('executeDelayedTransfer()', () => {
    beforeEach(async () => {
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[2], BN(10000).mul(MULTIPLIER).toString())
      await token.updateDailyLimit(BN(50).mul(MULTIPLIER).toString())
      await mine(60 * 60 * 48 + 1)
      await token.transfer(accounts[1], BN(20).mul(MULTIPLIER).toString(), { from: accounts[2] })
    })

    describe('when transferMethod is Transfer', () => {
      let txId, transferAmt

      beforeEach(async () => {
        transferAmt = BN(60).mul(MULTIPLIER)
        txId = await token.delayedTransfer.call(accounts[1], transferAmt)
        await token.delayedTransfer(accounts[1], transferAmt)
      })

      it('transfers the value from -> to', async () => {
        await mine(60 * 60 * 48 + 1)
        const previousToBalance = (await token.balanceOf(accounts[1]))
        const previousFromBalance = (await token.balanceOf(accounts[0]))

        await token.executeDelayedTransfer(txId)

        const currentToBalance = (await token.balanceOf(accounts[1]))
        const currentFromBalance = (await token.balanceOf(accounts[0]))

        expect(currentToBalance.sub(previousToBalance).toString()).to.equal(transferAmt.toString())
        expect(previousFromBalance.sub(currentFromBalance).toString()).to.equal(transferAmt.toString())
      })

      it('returns true', async () => {
        await mine(60 * 60 * 48 + 1)
        expect(await token.executeDelayedTransfer.call(txId)).to.equal(true)
      })

      it('reverts if countdown is not set', async () => {
        await shouldFail(token.executeDelayedTransfer(txId))
      })

      it('reverts if from is a zero address', async () => {
        await mine(60 * 60 * 48 + 1)
        await token.cancelDelayedTransfer(txId)
        await shouldFail(token.executeDelayedTransfer(txId))
      })
    })

    describe('when transferMethod is TransferFrom', async () => {
      let txId, transferAmt

      beforeEach(async () => {
        transferAmt = BN(60).mul(MULTIPLIER)
        txId = await token.delayedTransferFrom.call(
          accounts[0], accounts[1], transferAmt.toString()
        )
        await token.delayedTransferFrom(
          accounts[0], accounts[1], transferAmt.toString()
        )
      })

      it('sends the value from -> to', async () => {
        await mine(60 * 60 * 48 + 1)
        await token.approve(accounts[2], transferAmt)
        const previousToBalance = (await token.balanceOf(accounts[1]))
        const previousFromBalance = (await token.balanceOf(accounts[0]))

        await token.executeDelayedTransfer(txId, { from: accounts[2] })

        const currentToBalance = (await token.balanceOf(accounts[1]))
        const currentFromBalance = (await token.balanceOf(accounts[0]))

        expect(currentToBalance.sub(previousToBalance).toString()).to.equal(transferAmt.toString())
        expect(previousFromBalance.sub(currentFromBalance).toString()).to.equal(transferAmt.toString())
      })

      it('reverts if executing address has no allownance from "to"', async () => {
        await shouldFail(token.executeDelayedTransfer(txId, { from: accounts[2] }))
      })

      it('reverts if countdown is not set', async () => {
        await shouldFail(token.executeDelayedTransfer(txId))
      })

      it('reverts if from is a zero address', async () => {
        await mine(60 * 60 * 48 + 1)
        await token.cancelDelayedTransfer(txId)
        await shouldFail(token.executeDelayedTransfer(txId))
      })
    })
  })

  describe('cancelDelayedTransfer', () => {
    let txId, transferAmt

    describe('when TransferMethod is Transfer', () => {
      beforeEach(async () => {
        transferAmt = BN(60).mul(MULTIPLIER)
        txId = await token.delayedTransfer.call(
          accounts[1], transferAmt
        )
        await token.delayedTransfer(
          accounts[1], transferAmt
        )
      })

      it('deletes the delayedTransfer if sent by "from" for Transfer', async () => {
        expect((await token.delayedTransfers(txId)).to).to.equal(accounts[1])
        await token.cancelDelayedTransfer(txId)
        expect((await token.delayedTransfers(txId)).to).to.equal(ZERO_ADDR)
      })

      it('reverts if cancelled by address other than "from" for Transfer', async () => {
        await shouldFail(token.cancelDelayedTransfer(txId, { from: accounts[2] }))
      })

      it('returns true on successful cancellation', async () => {
        expect(await token.cancelDelayedTransfer.call(txId)).to.equal(true)
      })
    })

    describe('when TransferMethod is TransferFrom', () => {
      beforeEach(async () => {
        transferAmt = BN(60).mul(MULTIPLIER)
        txId = await token.delayedTransferFrom.call(
          accounts[0], accounts[1], transferAmt, { from: accounts[3] }
        )
        await token.delayedTransferFrom(
          accounts[0], accounts[1], transferAmt, { from: accounts[3] }
        )
        await token.approve(accounts[3], transferAmt)
      })

      it('deletes the delayedTransfer if sent by "from" for TransferFrom', async () => {
        expect((await token.delayedTransfers(txId)).to).to.equal(accounts[1])
        await token.cancelDelayedTransfer(txId)
        expect((await token.delayedTransfers(txId)).to).to.equal(ZERO_ADDR)
      })

      it('deletes the delayedTransfer if sent by sender for TransferFrom', async () => {
        expect((await token.delayedTransfers(txId)).to).to.equal(accounts[1])
        await token.cancelDelayedTransfer(txId, { from: accounts[3] })
        expect((await token.delayedTransfers(txId)).to).to.equal(ZERO_ADDR)
      })

      it('reverts if cancelled by address other than "from" or "sender"', async () => {
        await shouldFail(token.cancelDelayedTransfer(txId, { from: accounts[1] }))
      })
    })
  })

  describe('mint()', () => {
    it('mints new tokens if called by masterPropertyValue', async () => {
      const mintAmount = 500
      const previousTokenSupply = (await token.totalSupply())

      await assetsMock.mock_addTotalTokens(mintAmount)
      await masterPropertyValue.mock_callMint(token.address, accounts[0], mintAmount)

      const newTokenSupply = (await token.totalSupply())
      expect(newTokenSupply.toString()).to.equal(previousTokenSupply.add(BN(mintAmount)).toString())
    })

    it('reverts if called by address other than the mintingAdmin', async () => {
      await shouldFail(token.mint(accounts[0], 500, { from: accounts[0] }))
    })

    it('reverts if minting tokens to a non-whitelisted address', async () => {
      await assetsMock.mock_addTotalTokens(500)
      await shouldFail(masterPropertyValue.mock_callMint(token.address, accounts[4], 500))
    })
  })

  describe('burn()', () => {
    beforeEach(async () => {
      await assetsMock.mock_addTotalTokens(500)
      await masterPropertyValue.mock_callMint(token.address, accounts[0], 500)
    })

    it('burns tokens if called by redemptionAdmin', async () => {
      const burnAmount = 300
      const previousTokenSupply = (await token.totalSupply())

      await assetsMock.mock_subTotalTokens(burnAmount)
      await masterPropertyValue.mock_callBurn(token.address, accounts[0], burnAmount)

      const newTokenSupply = (await token.totalSupply()).toNumber()
      expect(newTokenSupply.toString()).to.equal(previousTokenSupply.sub(BN(burnAmount)).toString())
    })

    it('reverts if called by address other than the redemptionAdmin', async () => {
      await shouldFail(token.burn(accounts[0], 300, { from: accounts[0] }))
    })
  })

  describe('updateUpdateDailyLimitCountdownLength()', () => {
    it('updates the updateDailyLimitCountdownLength', async () => {
      expect((await token.updateDailyLimitCountdownLength()).toNumber())
        .to.equal(60 * 60 * 48)
      await token.updateUpdateDailyLimitCountdownLength(15, { from: superProtectorMultiSig })
      expect((await token.updateDailyLimitCountdownLength()).toNumber())
        .to.equal(15)
    })

    it('reverts if sent by address other than superProtectorMultiSig', async () => {
      await shouldFail(token.updateUpdateDailyLimitCountdownLength(15))
    })

    it('emits UpdateDailyLimitCountdownLengthUpdated event', async () => {
      const { logs } = await token.updateUpdateDailyLimitCountdownLength(
        10, { from: superProtectorMultiSig }
      )
      expect(logs[0].event).to.equal('UpdateDailyLimitCountdownLengthUpdated')
    })
  })

  describe('updatedelayedTransferCountdownLength()', () => {
    it('updates the delayedTransferCountdownLength', async () => {
      expect((await token.delayedTransferCountdownLength()).toNumber())
        .to.equal(60 * 60 * 48)
      await token.updateDelayedTransferCountdownLength(15, { from: superProtectorMultiSig })
      expect((await token.delayedTransferCountdownLength()).toNumber())
        .to.equal(15)
    })

    it('reverts if sent by address other than superProtectorMultiSig', async () => {
      await shouldFail(token.updateDelayedTransferCountdownLength(15))
    })

    it('emits UpdateDailyLimitCountdownLengthUpdated event', async () => {
      const { logs } = await token.updateDelayedTransferCountdownLength(
        10, { from: superProtectorMultiSig }
      )
      expect(logs[0].event).to.equal('DelayedTransferCountdownLengthUpdated')
    })
  })

  describe('detectTransferRestriction()', () => {
    beforeEach(async () => {
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[0], BN(10000).mul(MULTIPLIER).toString())
      await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
      await masterPropertyValue.mock_callMint(token.address, accounts[1], BN(10000).mul(MULTIPLIER).toString())
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
            BN(11).mul(MULTIPLIER))).toNumber()
        ).to.equal(0)
      })

      it('returns 1 if sending to a nonwhitelisted account', async () => {
        expect(
          (await token.detectTransferRestriction(
            accounts[0], nonWhitelistedAcct,
            BN(11).mul(MULTIPLIER))).toNumber()
        ).to.equal(1)
      })
    })

    describe('regarding daily limits', () => {
      let dailyLimit

      before(async () => {
        dailyLimit = BN(50).mul(MULTIPLIER)
      })

      it('returns 0 if there is no daily limit', async () => {
        await token.transfer(accounts[1], BN(40).mul(MULTIPLIER))
        expect(
          (await token.detectTransferRestriction(
            accounts[0], accounts[1],
            BN(11).mul(MULTIPLIER))).toNumber()
        ).to.equal(0)
      })

      describe('when new daily limit', () => {
        beforeEach(async () => {
          await token.updateDailyLimit(dailyLimit)
          await mine(60 * 60 * 48 + 1)
          await token.transfer(accounts[1], BN(40).mul(MULTIPLIER))
          await mine(60 * 60 * 24 + 1)
        })

        it('returns 0 if transfer limit does not exceed daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              BN(11).mul(MULTIPLIER))).toNumber()
          ).to.equal(0)
        })

        it('returns 2 if transfer value exceeds daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              BN(51).mul(MULTIPLIER))).toNumber()
          ).to.equal(2)
        })
      })

      describe('when still in previous daily limit period', () => {
        beforeEach(async () => {
          await token.updateDailyLimit(dailyLimit)
          await mine(60 * 60 * 48 + 1)
          await token.transfer(accounts[1], BN(40).mul(MULTIPLIER))
        })

        it('returns 0 if value + previous transfers does not exceed daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              BN(10).mul(MULTIPLIER))).toNumber()
          ).to.equal(0)
        })

        it('returns 2 if value + previous transfers exceeds daily limit', async () => {
          expect(
            (await token.detectTransferRestriction(
              accounts[0], accounts[1],
              BN(11).mul(MULTIPLIER))).toNumber()
          ).to.equal(2)
        })
      })
    })
  })

  describe('messageForTransferRestriction()', () => {
    let validTransferMsg, dailyLimitMsg, whitelistMsg

    before(async () => {
      validTransferMsg = 'Valid transfer'
      whitelistMsg = 'Invalid transfer: nonwhitelisted recipient'
      dailyLimitMsg = 'Invalid transfer: exceeds daily limit'
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

  describe('sweep addresses', () => {
    const basicProtectorMultiSig = accounts[6]

    beforeEach(async () => {
      if (await token.basicProtectorMultiSig.call() === ZERO_ADDR) {
        await token.initializeBasicProtectorMultiSig(basicProtectorMultiSig)
      }
    })

    describe('updateSweepAddress()', () => {
      it('derive sweep address', async () => {
        const address1 = '0x1111111111111111111111111111111111111111'
        const address2 = '0x1111111111111111111111111111111111199999'
        const address3 = '0x1111111111111111111111111111111111199999'
        const sweepAddress = '0x0000011111111111111111111111111111111111'

        expect(await token.computeSweepAddress.call(address1)).to.equal(sweepAddress)
        expect(await token.computeSweepAddress.call(address2)).to.equal(sweepAddress)
        expect(await token.computeSweepAddress.call(address3)).to.equal(sweepAddress)
      })

      it('map an exchange address to a sweep address', async () => {
        const address1 = '0x1111111111111111111111111111111111111111'
        const address2 = '0x0000000000000000000000000000000000011111'
        const exchangeAddress = '0x9999999999999999999999999999999999999999'

        await token.updateSweepAddress(address1, exchangeAddress, {
          from: basicProtectorMultiSig
        })

        await shouldFail(token.updateSweepAddress(address2, exchangeAddress, {
          from: basicProtectorMultiSig
        }))
      })

      it('returns the exchange address for sweep address', async () => {
        const address = '0x1111111111111111111111111111111111111111'
        const sweepAddress = '0x0000011111111111111111111111111111111111'
        const exchangeAddress = '0x9999999999999999999999999999999999999999'

        await token.updateSweepAddress(address, exchangeAddress, {
          from: basicProtectorMultiSig
        })

        expect(await token.sweepAddresses.call(sweepAddress)).to.equal(exchangeAddress)
      })
    })

    describe('transfer() to sweep address', () => {
      beforeEach(async () => {
        await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
        await masterPropertyValue.mock_callMint(token.address, accounts[0], (BN(10000).mul(MULTIPLIER)).toString())
      })

      it('transfers token to sweep address', async () => {
        const address1 = '0x1111111111111111111111111111111111100000'
        const address2 = '0x1111111111111111111111111111111111100001'
        const address3 = '0x1111111111111111111111111111111111100002'
        const sweepAddress = '0x0000011111111111111111111111111111111111'
        const exchangeAddress = '0x9999999999999999999999999999999999999999'
        const nonSweepAddress = '0x3333333333333333333333333333333333333333'

        await whitelist.addWhitelisted(sweepAddress)
        await whitelist.addWhitelisted(exchangeAddress)
        await whitelist.addWhitelisted(nonSweepAddress)

        await token.updateSweepAddress(address1, exchangeAddress, {
          from: basicProtectorMultiSig
        })

        expect((await token.balanceOf(exchangeAddress)).toString()).to.equal('0')
        const tx1 = await token.transfer(address2, 100)
        const tx2 = await token.transfer(address3, 100)
        const tx3 = await token.transfer(nonSweepAddress, 50)
        expect((await token.balanceOf(exchangeAddress)).toString()).to.equal('200')
        expect((await token.balanceOf(nonSweepAddress)).toString()).to.equal('50')

        expect(tx1.logs[0].event).to.equal('Transfer')
        expect(tx1.logs[0].args[0]).to.equal(accounts[0])
        expect(tx1.logs[0].args[1]).to.equal(exchangeAddress)
        expect(tx1.logs[0].args[2].toString()).to.equal('100')

        expect(tx1.logs[1].event).to.equal('OriginalTransfer')
        expect(tx1.logs[1].args[0]).to.equal(accounts[0])
        expect(tx1.logs[1].args[1]).to.equal(address2)
        expect(tx1.logs[1].args[2].toString()).to.equal('100')

        expect(tx2.logs.length).to.equal(2)
        expect(tx3.logs.length).to.equal(1)
      })
    })

    describe('transferFrom() to sweep address', () => {
      beforeEach(async () => {
        await assetsMock.mock_addTotalTokens((BN(10000).mul(MULTIPLIER)).toString())
        await masterPropertyValue.mock_callMint(token.address, accounts[0], (BN(10000).mul(MULTIPLIER)).toString())
      })

      it('transfers token to sweep address', async () => {
        const address1 = '0x1111111111111111111111111111111111100000'
        const address2 = '0x1111111111111111111111111111111111100001'
        const address3 = '0x1111111111111111111111111111111111100002'
        const sweepAddress = '0x0000011111111111111111111111111111111111'
        const exchangeAddress = '0x9999999999999999999999999999999999999999'
        const nonSweepAddress = '0x3333333333333333333333333333333333333333'

        await whitelist.addWhitelisted(sweepAddress)
        await whitelist.addWhitelisted(exchangeAddress)
        await whitelist.addWhitelisted(nonSweepAddress)

        await token.updateSweepAddress(address1, exchangeAddress, {
          from: basicProtectorMultiSig
        })

        await token.approve(accounts[0], 10000, { from: accounts[0] })

        expect((await token.balanceOf(exchangeAddress)).toString()).to.equal('0')
        const tx1 = await token.transferFrom(accounts[0], address2, 100)
        const tx2 = await token.transferFrom(accounts[0], address3, 100)
        const tx3 = await token.transferFrom(accounts[0], nonSweepAddress, 50)
        expect((await token.balanceOf(exchangeAddress)).toString()).to.equal('200')
        expect((await token.balanceOf(nonSweepAddress)).toString()).to.equal('50')

        expect(tx1.logs[0].event).to.equal('Transfer')
        expect(tx1.logs[0].args[0]).to.equal(accounts[0])
        expect(tx1.logs[0].args[1]).to.equal(exchangeAddress)
        expect(tx1.logs[0].args[2].toString()).to.equal('100')
        expect(tx1.logs[1].event).to.equal('Approval')

        expect(tx1.logs[2].event).to.equal('OriginalTransfer')
        expect(tx1.logs[2].args[0]).to.equal(accounts[0])
        expect(tx1.logs[2].args[1]).to.equal(address2)
        expect(tx1.logs[2].args[2].toString()).to.equal('100')

        expect(tx2.logs.length).to.equal(3)
        expect(tx3.logs.length).to.equal(2)
      })
    })
  })
})
