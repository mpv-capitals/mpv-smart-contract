const { shouldFail } = require('openzeppelin-test-helpers')
require('chai').should()

const MPVToken = artifacts.require('MPVToken')
const Whitelist = artifacts.require('Whitelist')
const MasterPropertyValueMock = artifacts.require('MasterPropertyValueMock')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')

const MULTIPLIER = 10 ** 4

contract('MPVToken', accounts => {
  let token, whitelist, masterPropertyValue

  beforeEach(async () => {
    masterPropertyValue = await MasterPropertyValueMock.new()
    await masterPropertyValue.mock_setPaused(false)
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    whitelist = await Whitelist.new()
    await whitelist.initialize(multiSig.address)
    token = await MPVToken.new()
    await token.initialize('Master Property Value', 'MPV', 4, whitelist.address, masterPropertyValue.address)

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
      await token.transferFrom(accounts[1], accounts[0], 500 * MULTIPLIER)
      await shouldFail(token.transferFrom(accounts[1], accounts[0], 501 * MULTIPLIER))
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
})
