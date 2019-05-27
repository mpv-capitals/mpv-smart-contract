pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./MasterPropertyValue.sol";


/**
 * @title SuperProtectorRole
 * @dev Super protector role contract.
 */
contract SuperProtectorRole is Initializable {
    /*
     *  Events
     */
    event TransferLimitChangeCountdownUpdated(address indexed sender, uint256 indexed countdown);
    event DelayTransferCountdownUpdated(address indexed sender, uint256 indexed countdown);
    event WhitelistRemovalCountdownUpdated(address indexed sender, uint256 indexed countdown);

    /*
     *  Storage
     */
    IMultiSigWallet public superProtectorMultiSig;
    uint256 public transferLimitChangeCountdownLength;
    uint256 public delayedTransferCountdownLength;
    uint256 public whitelistRemovalActionCountdownLength;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    modifier onlySuperProtectorMultiSig() {
        require(address(superProtectorMultiSig) == msg.sender);
        _;
    }

    /// @dev Requires that the MPV contract is not paused.
    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function set initial storage values.
    /// @param _superProtectorMultiSig Address of the super protector multisig.
    function initialize(
        IMultiSigWallet _superProtectorMultiSig,
        MasterPropertyValue _masterPropertyValue
    ) public initializer {
        superProtectorMultiSig = _superProtectorMultiSig;
        masterPropertyValue = _masterPropertyValue;

        transferLimitChangeCountdownLength = 48 hours;
        delayedTransferCountdownLength = 48 hours;
        whitelistRemovalActionCountdownLength = 48 hours;
    }

    /// @dev Set the countdown length from when there's a transfer limit change.
    /// Transaction has to be sent by the super protector multisig.
    /// @param newCountdown New countdown length.
    function updateTransferLimitChangeCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        transferLimitChangeCountdownLength = newCountdown;
        emit TransferLimitChangeCountdownUpdated(msg.sender, newCountdown);
    }

    /// @dev Set the delayed transfer countdown length. Transaction has to be
    /// sent by the super protector multisig.
    /// @param newCountdown New countdown length.
    function updateDelayedTransferCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        delayedTransferCountdownLength = newCountdown;
        emit DelayTransferCountdownUpdated(msg.sender, newCountdown);
    }

    /// @dev Set the countdown length for the whitelist removal action.
    /// Transaction has to be sent by the super protector multisig.
    /// @param newCountdown New countdown length.
    function updateWhitelistRemovalActionCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        whitelistRemovalActionCountdownLength = newCountdown;
        emit WhitelistRemovalCountdownUpdated(msg.sender, newCountdown);
    }
}
