const iota = (() => { let n = 0; return () => n++ })()

// NOTE: these should be in the same as defined in the `Status`
// enum in Solidity Assets contract
module.exports = {
  PENDING: iota(),
  ENLISTED: iota(),
  LOCKED: iota(),
  REDEEMED: iota(),
  RESERVED: iota(),
}
