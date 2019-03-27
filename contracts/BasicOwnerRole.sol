pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./MintingAdminRole.sol";


contract BasicOwnerRole is Initializable {
    IMultiSigWallet public multiSig;
    MintingAdminRole public mintingAdminRole;

    modifier onlyMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    modifier onlyOwner() {
        require(multiSig.hasOwner(msg.sender));
        _;
    }

    function initialize(
        IMultiSigWallet _multiSig,
        MintingAdminRole _mintingAdminRole
    ) public initializer {
        multiSig = _multiSig;
        mintingAdminRole = _mintingAdminRole;
    }

    function cancelMinting()
        public
        onlyOwner
    {
        mintingAdminRole.cancelMinting();
    }
}
