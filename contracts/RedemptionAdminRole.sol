pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";


contract RedemptionAdminRole is Initializable {
    IMultiSigWallet public multiSig;

    /*
    function initialize(
        //IMultiSigWallet _multiSig,
    ) public initializer {
        //multiSig = _multiSig;
    }
    */
}
