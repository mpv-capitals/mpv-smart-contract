const { shouldFail } = require('openzeppelin-test-helpers')
require('chai').should()

const MPVToken = artifacts.require('MPVToken')
const Whitelist = artifacts.require('Whitelist')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')

contract('MPVToken', accounts => {
  let token, whitelist, mintingAdmin, redemptionAdmin

  beforeEach(async () => {
    mintingAdmin = accounts[5]
    redemptionAdmin = accounts[6]
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    whitelist = await Whitelist.new()
    await whitelist.initialize(multiSig.address)
    token = await MPVToken.new()
    await token.initialize('Master Property Value', 'MPV', 4, whitelist.address, mintingAdmin, redemptionAdmin)

    await whitelist.addWhitelisted(accounts[0])
    await whitelist.addWhitelisted(accounts[1])
    await whitelist.addWhitelisted(accounts[2])
  })

  describe('transfer()', () => {
    beforeEach(async () => {
      await token.mint(accounts[0], 500, { from: mintingAdmin })
      await token.mint(accounts[1], 500, { from: mintingAdmin })
    })

    it('sends tokens to whitelisted addresses', async () => {
      (await token.transfer.call(accounts[1], 30)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transfer(accounts[3], 30))
    })
  })

  describe('transferFrom()', () => {
    beforeEach(async () => {
      await token.approve(accounts[0], 500, {from: accounts[1]})
      await token.mint(accounts[1], 500, { from: mintingAdmin })
    })

    it('sends tokens to whitelisted addresses', async () => {
      (await token.transferFrom.call(accounts[1], accounts[2], 20)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transferFrom.call(accounts[1], accounts[3], 20))
    })
  })

  describe('mint()', () => {
    it('mints new tokens if called by mintingAdming', async () => {
      const mintAmount = 500
      const previousTokenSupply = (await token.totalSupply()).toNumber()

      await token.mint(accounts[0], mintAmount, { from: mintingAdmin })

      const newTokenSupply = (await token.totalSupply()).toNumber()
      newTokenSupply.should.equal(previousTokenSupply + mintAmount)
    })

    it('reverts if called by address other than the mintingAdmin', async () => {
      await shouldFail(token.mint(accounts[0], 500, { from: accounts[0]}))
    })
  })

  describe('burn()', () => {
    beforeEach(async () => {
      await token.mint(accounts[0], 500, { from: mintingAdmin })
    })

    it('burns tokens if called by redemptionAdmin', async () => {
      const burnAmount = 300
      const previousTokenSupply = (await token.totalSupply()).toNumber()

      await token.burn(accounts[0], burnAmount, { from: redemptionAdmin })

      const newTokenSupply = (await token.totalSupply()).toNumber()
      newTokenSupply.should.equal(previousTokenSupply - burnAmount)
    })

    it('reverts if called by address other than the redemptionAdmin', async () => {
      await shouldFail(token.burn(accounts[0], 300, { from: accounts[0]}))
    })
  })
})
