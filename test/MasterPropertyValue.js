const MPV = artifacts.require('./MasterPropertyValue.sol');
const moment = require('moment');

/*
function getLastEvent (instance) {
  return new Promise((resolve, reject) => {
    instance.getPastEvents({
      fromBlock: 0,
      toBlock: 'latest',
    }, (error, log) => {
      if (error) return reject(error);
      resolve(log[0]);
    });
  });
}
*/

contract('MPV', accounts => {
  let instance = null;

  before('instantiate contract', async () => {
    try {
      instance = await MPV.new();
    } catch (error) {
      // console.error(error)
      assert.equal(error, undefined);
    }
  });

  it.skip('add assets', async () => {
    // const account = accounts[0];

    try {
      const assets = [{
        id: 2,
        state: 2,
        valuation: 50,
        fingerprint: '0xabcd',
        countdown: moment().unix(),
      }, {
        id: 3,
        state: 1,
        valuation: 70,
        fingerprint: '0x1234',
        countdown: moment().unix() + 1000,
      }];
      const result = await instance.addAssets(assets);
      console.log(result);

      const data = await web3.eth.getTransaction(result.tx);
      console.log(data);

      // const results = await instance.assets.call(2)
      // console.log(results)
    } catch (error) {
      // console.error(error)
      assert.equal(error, undefined);
    }
  });
});
