module.exports = async function mine(durationSeconds) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [durationSeconds],
      id: Date.now()
    }, (err, resp) => {
      if (err) {
        return reject(err)
      }

      resolve()
    })
  })
}
