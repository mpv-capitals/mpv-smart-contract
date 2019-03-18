const { shouldFail } = require('openzeppelin-test-helpers')
require('chai').should()

const MPVToken = artifacts.require('MPVToken')
const Whitelist = artifacts.require('Whitelist')
const OperationAdminMultiSigWalletMock = artifacts.require('OperationAdminMultiSigWalletMock')

contract.only('MPVToken', accounts => {
  let whitelist
  let token

  beforeEach(async () => {
    const multiSig = await OperationAdminMultiSigWalletMock.new([accounts[0], accounts[1]], 2)
    whitelist = await Whitelist.new()
    await whitelist.initialize(multiSig.address)
    token = await MPVToken.new()
    await token.initialize('Master Property Value', 'MPV', 4, whitelist.address)

    await token.mint(accounts[0], 500)
    await token.mint(accounts[1], 500)
    await whitelist.addWhitelisted(accounts[0])
    await whitelist.addWhitelisted(accounts[1])
    await whitelist.addWhitelisted(accounts[2])
  })

  describe('transfer()', () => {
    it('sends tokens to whitelisted addresses', async () => {
      (await token.transfer.call(accounts[1], 30)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transfer(accounts[3], 30))
    })
  })

  describe('transferFrom()', () => {
    beforeEach(async () => {
      await token.approve(accounts[0], 20, {from: accounts[1]})
    })

    it('sends tokens to whitelisted addresses', async () => {
      (await token.transferFrom.call(accounts[1], accounts[2], 20)).should.equal(true)
    })

    it('reverts if transferring to non-whitelisted address', async () => {
      await shouldFail(token.transferFrom.call(accounts[1], accounts[3], 20))
    })
  })
})
