pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./MPVToken.sol";
import "./Assets.sol";

contract RedemptionAdminRole is Initializable {
    IMultiSigWallet public multiSig;
    Assets assets;
    uint256 public burningActionCountdownLength;
    mapping(uint256 => uint256) public redemptionCountdowns;

    modifier onlyRedemptionAdminMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    function initialize(
        IMultiSigWallet _multiSig,
        Assets _assets
    ) public initializer {
        multiSig = _multiSig;
        assets = _assets;
        burningActionCountdownLength = 48 hours;
    }

    function startBurningCountdown(uint256 assetId)
    public onlyRedemptionAdminMultiSig
    {
        redemptionCountdowns[assetId] = now;
    }
}
