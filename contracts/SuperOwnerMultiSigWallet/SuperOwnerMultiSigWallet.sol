pragma solidity >=0.4.21 <0.6.0;

import "../BaseMultiSigWallet/BaseMultiSigWallet.sol";

/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.
/// @author Stefan George - <stefan.george@consensys.net>
contract SuperOwnerMultiSigWallet is BaseMultiSigWallet {
    constructor(address[] memory _owners, uint _required)
        public
        BaseMultiSigWallet(_owners, _required)
    {

    }
}
