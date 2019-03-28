pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";


contract SuperOwnerRole is Initializable {
    IMultiSigWallet public multiSig;

    uint256 public transferLimitChangeCountdownLength;
    uint256 public delayedTransferCountdownLength;
    uint256 public superOwnerActionCountdownLength;
    uint256 public basicOwnerActionCountdownLength;
    uint256 public whitelistRemovalActionCountdownLength;
    uint256 public mintingActionCountdownLength;
    uint256 public burningActionCountdownLength;

    address public mintingReceiverWallet;

    modifier onlyMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    function initialize(
        IMultiSigWallet _multiSig,
        address _mintingReceiverWallet
    ) public initializer {
        require(_mintingReceiverWallet != address(0));

        multiSig = _multiSig;
        mintingReceiverWallet = _mintingReceiverWallet;

        transferLimitChangeCountdownLength = 48 hours;
        delayedTransferCountdownLength = 48 hours;
        superOwnerActionCountdownLength = 48 hours;
        basicOwnerActionCountdownLength = 48 hours;
        whitelistRemovalActionCountdownLength = 48 hours;
        mintingActionCountdownLength = 48 hours;
        burningActionCountdownLength = 48 hours;
    }

    function setTransferLimitChangeCountdownLength(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        transferLimitChangeCountdownLength = newCountdown;
    }

    function setDelayedTransferCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        delayedTransferCountdownLength = newCountdown;
    }

    function setSuperOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        superOwnerActionCountdownLength = newCountdown;
    }

    function setBasicOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        basicOwnerActionCountdownLength = newCountdown;
    }

    function setWhitelistRemovalActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        whitelistRemovalActionCountdownLength = newCountdown;
    }

    function setBurningActionCountdown(
        uint256 newCountdown
    )
    public
    onlyMultiSig
    {
        burningActionCountdownLength = newCountdown;
    }

    function setMintingReceiverWallet(
        address newWallet
    )
    public
    onlyMultiSig
    {
        require(newWallet != address(0));
        mintingReceiverWallet = newWallet;
    }
}
