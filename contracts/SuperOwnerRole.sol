pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";


/**
 * @title SuperOwnerRole
 * @dev Super owner role contract.
 */
contract SuperOwnerRole is Initializable {
    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    uint256 public transferLimitChangeCountdownLength;
    uint256 public delayedTransferCountdownLength;
    uint256 public whitelistRemovalActionCountdownLength;
    uint256 public burningActionCountdownLength;

    /*
     *  Modifiers
     */
    modifier onlyMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function set initial storage values.
    /// @param _multiSig Address of the super owner multisig.
    function initialize(
        IMultiSigWallet _multiSig
    ) public initializer {
        multiSig = _multiSig;

        transferLimitChangeCountdownLength = 48 hours;
        delayedTransferCountdownLength = 48 hours;
        whitelistRemovalActionCountdownLength = 48 hours;
    }

    /// @dev Set the countdown length from when there's a transfer limit change.
    /// Transaction has to be sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function setTransferLimitChangeCountdownLength(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        transferLimitChangeCountdownLength = newCountdown;
    }

    /// @dev Set the delayed transfer countdown length. Transaction has to be
    /// sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function setDelayedTransferCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        delayedTransferCountdownLength = newCountdown;
    }

    /// @dev Set the countdown length for the whitelist removal action.
    /// Transaction has to be sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function setWhitelistRemovalActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        whitelistRemovalActionCountdownLength = newCountdown;
    }

    /// @dev Set the countdown length for the action of burning of tokens.
    /// Transaction has to be sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function setBurningActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        burningActionCountdownLength = newCountdown;
    }
}
