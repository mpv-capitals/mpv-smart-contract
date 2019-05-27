pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./MintingAdminRole.sol";

/**
 * @title BasicProtectorRole
 * @dev Basic protector role contract.
 */
contract BasicProtectorRole is Initializable {
    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    MintingAdminRole public mintingAdminRole;

    /*
     *  Modifiers
     */
    /// Requires that the sender is an owner in the basic protector multisig contract.
    modifier onlyOwner() {
        require(multiSig.hasOwner(msg.sender));
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param _multiSig Address of the basic owner multisig contract.
    function initialize(
        IMultiSigWallet _multiSig
    ) public initializer {
        multiSig = _multiSig;
    }
}