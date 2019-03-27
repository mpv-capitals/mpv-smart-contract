pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./Assets.sol";
import "./MPVToken.sol";
import "./SuperOwnerRole.sol";


contract MintingAdminRole is Initializable {
    IMultiSigWallet public multiSig;
    uint256 public mintingActionCountdownLength;
    uint256 public mintingCountdownStart;
    uint256 public pendingAssetsTransactionId;
    Assets public assets;
    MPVToken public mpvToken;
    SuperOwnerRole public superOwnerRole;

    modifier onlyMintingAdminMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    function initialize(
        IMultiSigWallet _multiSig,
        Assets _assets,
        MPVToken _mpvToken,
        SuperOwnerRole _superOwnerRole
    ) public initializer {
        multiSig = _multiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        superOwnerRole = _superOwnerRole;
        mintingActionCountdownLength = 48 hours;
    }

    function setMintingActionCountdown(
        uint256 newCountdown
    )
    public
   // onlyMintingAdminMultiSig
    {
        mintingActionCountdownLength = newCountdown;
    }

    function addPendingAsset(Assets.Asset memory _asset)
    public
    returns (uint256) {
        // minting countdown terminated
        require(mintingCountdownStart == 0);
        if (!(assets.pendingAssetsCount() > 0 || pendingAssetsTransactionId != 0)) {
            assets.addPendingAsset(_asset);
            bytes memory data = abi.encodeWithSelector(
                this._startMintingCountdown.selector
            );

            uint256 transactionId = multiSig.addTransaction(address(this), data);
            pendingAssetsTransactionId = transactionId;
            return transactionId;
        } else {
            assets.addPendingAsset(_asset);
            multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
            return pendingAssetsTransactionId;
        }
    }

    function addPendingAssets(Assets.Asset[] memory _assets)
    public
    returns (uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            addPendingAsset(_assets[i]);
        }

        return pendingAssetsTransactionId;
    }

    function _startMintingCountdown()
    public
    onlyMintingAdminMultiSig
    {
        mintingCountdownStart = now;
    }

    function refreshPendingAssetsStatus()
    public
    {
        require(now >= mintingCountdownStart + mintingActionCountdownLength);
        _enlistPendingAssets();
    }

    function removePendingAsset(uint256 assetId)
    public
    returns (uint256)
    {
        assets.removePendingAsset(assetId);

        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        return pendingAssetsTransactionId;
    }

    function cancelMinting()
    public {
        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        mintingCountdownStart = 0;
    }

    function _enlistPendingAssets()
    internal {
        Assets.Asset[] memory _assets = assets.getPendingAssets();
        for (uint256 i = 0; i < _assets.length; i++) {
            _enlistPendingAsset(_assets[i]);
        }

        // reset pending assets
        pendingAssetsTransactionId = 0;
        assets.resetPendingAssets();
        mintingCountdownStart = 0;
    }

    function _enlistPendingAsset(Assets.Asset memory asset)
    internal {
        asset.status = Assets.Status.ENLISTED;
        assets.add(asset);
        mpvToken.mint(superOwnerRole.mintingReceiverWallet(), asset.tokens);
    }
}
