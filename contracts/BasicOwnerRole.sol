pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./MintingAdminRole.sol";


/**
 * @title BasicOwnerRole
 * @dev Basic owner role contract.
 */
contract BasicOwnerRole is Initializable {
    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    MintingAdminRole public mintingAdminRole;

    /*
     *  Modifiers
     */
    /// Requires that the sender is an owner in the basic owner multisig contract.
    modifier onlyOwner() {
        require(multiSig.hasOwner(msg.sender));
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param _multiSig Address of the basic owner multisig contract.
    /// @param _mintingAdminRole Address of the minting admin role contract.
    function initialize(
        IMultiSigWallet _multiSig,
        MintingAdminRole _mintingAdminRole
    ) public initializer {
        multiSig = _multiSig;
        mintingAdminRole = _mintingAdminRole;
    }

    /// @dev Cancels the minting of new tokens. Transaction has to be sent by a
    /// basic owner.
    function cancelMinting()
        public
        onlyOwner
    {
        mintingAdminRole.cancelMinting();
    }
}
