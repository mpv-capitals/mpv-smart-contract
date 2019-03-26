pragma solidity ^0.5.1;

import "./IMultiSigWallet.sol";
import "./IWhitelist.sol";
import "./Assets.sol";
import "./MPVToken.sol";


library MPVState {
    struct Asset {
        uint256 id;
        bytes32 notarizationId;
        uint256 tokens;
    }

    struct State {
        MPVToken mpvToken;

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

        uint256 superOwnerActionCountdownLength;
        uint256 basicOwnerActionCountdownLength;
        uint256 whitelistRemovalActionCountdownLength;
        uint256 mintingActionCountdownLength;
        uint256 burningActionCountdownLength;

        uint256 mintingCountownStart;

        address mintingReceiverWallet;
        uint256 redemptionFee;
        address redemptionFeeReceiverWallet;
        Asset[] pendingAssets;
        uint256 pendingAssetsTransactionId;
    }
}
