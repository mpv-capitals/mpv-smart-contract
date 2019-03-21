pragma solidity >=0.4.21 <0.6.0;

import "./IMultiSigWallet.sol";
import './IWhitelist.sol';
import "./Assets.sol";


library MPVState {
    struct Asset {
        uint256 id;
        uint256 valuation;
        bytes32 fingerprint;
        uint256 tokens;
    }
    struct State {
        IMultiSigWallet operationAdminMultiSig;
        IMultiSigWallet mintingAdminMultiSig;
        IMultiSigWallet redemptionAdminMultiSig;

        IWhitelist whitelist;
        uint dailyTransferLimit;

        Assets.State assets;

        uint256 superOwnerActionThresholdPercent;
        uint256 basicOwnerActionThresholdPercent;
        uint256 operationAdminActionThresholdPercent;
        uint256 mintingAdminActionThresholdPercent;
        uint256 redemptionAdminActionThresholdPercent;

        uint256 mintingAdminStartMintingCountdownThresholdPercent;
        uint256 redemptionAdminStartBurningCountdownThresholdPercent;

        uint256 superOwnerActionCountdown;
        uint256 basicOwnerActionCountdown;
        uint256 whitelistRemovalActionCountdown;
        uint256 mintingActionCountdown;
        uint256 burningActionCountdown;

        address mintingReceiverWallet;
        uint256 redemptionFee;
        address redemptionFeeReceiverWallet;
        Asset[] pendingAssets;
        uint256 pendingAssetsTransactionId;
    }
}
