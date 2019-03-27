pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";


contract SuperOwnerRole is Initializable {
    IMultiSigWallet public superOwnerMultiSig;

    uint256 public transferLimitChangeCountdownLength;
    address public mintingReceiverWallet;

    modifier onlySuperOwnerMultiSig() {
        require(address(superOwnerMultiSig) == msg.sender);
        _;
    }

    function initialize(
        IMultiSigWallet _superOwnerMultiSig,
        address _mintingReceiverWallet
    ) public initializer {
        superOwnerMultiSig = _superOwnerMultiSig;
        mintingReceiverWallet = _mintingReceiverWallet;
        transferLimitChangeCountdownLength = 48 hours;

        //superOwnerActionCountdownLength = 48 hours;
        //basicOwnerActionCountdownLength = 48 hours;
        //whitelistRemovalActionCountdownLength = 48 hours;
        //mintingActionCountdownLength = 48 hours;
        //burningActionCountdownLength = 48 hours;
    }

    function setTransferLimitChangeCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        transferLimitChangeCountdownLength = newCountdown;
    }

    function setSuperOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        //superOwnerActionCountdown = newCountdown;
    }

    function setBasicOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        //basicOwnerActionCountdown = newCountdown;
    }

    function setWhitelistRemovalActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        //whitelistRemovalActionCountdown = newCountdown;
    }

    function setBurningActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        //burningActionCountdown = newCountdown;
    }

    function setMintingReceiverWallet(
        address newWallet
    )
    public
    onlySuperOwnerMultiSig
    {
        mintingReceiverWallet = newWallet;
    }
}
