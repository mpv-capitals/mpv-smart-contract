const iota = (() => { let n = 0; return () => n++ })()

// NOTE: these should be in the same as defined in the `Actions`
// enum in Solidity MasterPropertyValue contract
module.exports = {
  setSuperOwnerActionThresholdPercent: iota(),
  setRedemptionFee: iota(),
  setRedemptionFeeReceiverWallet: iota(),
  setSuperOwnerActionCountdown: iota(),
  setBasicOwnerActionCountdown: iota(),
  setWhitelistRemovalActionCountdown: iota(),
  setMintingActionCountdown: iota(),
  setBurningActionCountdown: iota(),
  setMintingReceiverWallet: iota(),
  addOwner: iota(),
  removeOwner: iota()
}
