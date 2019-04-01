const iota = (() => { let n = 0; return () => n++ })()

// NOTE: these should be in the same as defined in the `Status`
// enum in Solidity Assets contract
module.exports = {
  Pending: iota(),
  Enlisted: iota(),
  Locked: iota(),
  Redeemed: iota(),
  Reserved: iota(),
}
