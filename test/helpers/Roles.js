const iota = (() => { let n = 0; return () => n++ })()

// NOTE: these should be in the same as defined in the `Roles`
// enum in Solidity MasterPropertyValue contract
module.exports = {
  SuperProtector: iota(),
  BasicProtector: iota(),
  OperationAdmin: iota(),
  MintingAdmin: iota(),
  RedemptionAdmin: iota(),
}
