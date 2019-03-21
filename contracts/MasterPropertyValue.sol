pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./IMultiSigWallet.sol";
import './IWhitelist.sol';
import "./Assets.sol";
import "./Pausable.sol";
import "./MPVState.sol";
import "./SuperOwnerRole.sol";
import "./BasicOwnerRole.sol";
import "./OperationAdminRole.sol";
import "./MintingAdminRole.sol";
import "./RedemptionAdminRole.sol";


contract MasterPropertyValue is Initializable, Pausable {
    using Assets for Assets.State;
    using SafeMath for uint256;
    using MPVState for MPVState.State;
    using SuperOwnerRole for SuperOwnerRole.State;
    using BasicOwnerRole for BasicOwnerRole.State;
    using OperationAdminRole for OperationAdminRole.State;
    using MintingAdminRole for MintingAdminRole.State;
    using RedemptionAdminRole for RedemptionAdminRole.State;

    MPVState.State private state;
    SuperOwnerRole.State private superOwnerRole;
    BasicOwnerRole.State private basicOwnerRole;
    OperationAdminRole.State private operationAdminRole;
    MintingAdminRole.State private mintingAdminRole;
    RedemptionAdminRole.State private redemptionAdminRole;

    event LogSuperOwnerAdded(address superOwner);
    event LogSuperOwnerRemoved(address superOwner);

    event LogBasicOwnerAdded(address basicOwner);
    event LogBasicOwnerRemoved(address basicOwner);

    event LogOperationAdminAdded(address operationAdmin);
    event LogOperationAdminRemoved(address operationAdmin);

    event LogMintingAdminAdded(address mintingAdmin);
    event LogMintingAdminRemoved(address mintingAdmin);

    event LogRedemptionAdminAdded(address redemptionAdmin);
    event LogRedemptionAdminRemoved(address redemptionAdmin);

    event LogAddAsset(uint256 assetId);
    event LogRemoveAsset(uint256 assetId);

    function initialize(
        IMultiSigWallet _superOwnerMultiSig,
        IMultiSigWallet _basicOwnerMultiSig,
        IMultiSigWallet _operationAdminMultiSig,
        IMultiSigWallet _mintingAdminMultiSig,
        IMultiSigWallet _redemptionAdminMultiSig,
        IWhitelist _whitelist,
        address _mintingReceiverWallet,
        uint _dailyTransferLimit
    ) public initializer {
        superOwnerRole.superOwnerMultiSig = _superOwnerMultiSig;
        basicOwnerRole.basicOwnerMultiSig = _basicOwnerMultiSig;
        operationAdminRole.operationAdminMultiSig = _operationAdminMultiSig;
        mintingAdminRole.mintingAdminMultiSig = _mintingAdminMultiSig;
        redemptionAdminRole.redemptionAdminMultiSig = _redemptionAdminMultiSig;

        state.whitelist = _whitelist;
        state.mintingReceiverWallet = _mintingReceiverWallet;

        state.dailyTransferLimit = _dailyTransferLimit;

        state.superOwnerActionThresholdPercent = 40;
        state.basicOwnerActionThresholdPercent = 100;
        state.operationAdminActionThresholdPercent = 100;
        state.mintingAdminActionThresholdPercent = 100;
        state.redemptionAdminActionThresholdPercent = 100;

        state.mintingAdminStartMintingCountdownThresholdPercent = 100;
        state.redemptionAdminStartBurningCountdownThresholdPercent = 100;

        state.superOwnerActionCountdown = 48 hours;
        state.basicOwnerActionCountdown = 48 hours;
        state.whitelistRemovalActionCountdown = 48 hours;
        state.mintingActionCountdown = 48 hours;
        state.burningActionCountdown = 48 hours;

        // NOTE: default is 0.1 tokens
        // 1000 = 0.1 * (10 ** 4)
        state.redemptionFee = 1000;
    }

    modifier onlySuperOwnerMultiSig() {
        require(msg.sender == address(superOwnerRole.superOwnerMultiSig));
        _;
    }

    modifier onlySuperOwner() {
        require(_isOwner(superOwnerRole.superOwnerMultiSig, msg.sender));
        _;
    }

    modifier onlyBasicOwner() {
        require(_isOwner(basicOwnerRole.basicOwnerMultiSig, msg.sender));
        _;
    }

    modifier onlyBasicOwnerMultiSig() {
        require(msg.sender == address(basicOwnerRole.basicOwnerMultiSig));
        _;
    }

    modifier onlyMintingAdmin() {
        require(_isOwner(operationAdminRole.operationAdminMultiSig, msg.sender));
        _;
    }

    modifier onlyMintingAdminMultiSig() {
        require(msg.sender == address(mintingAdminRole.mintingAdminMultiSig));
        _;
    }

    function setRedemptionFee(uint256 newRedemptionFee)
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setRedemptionFee(
            this._setRedemptionFee.selector,
            newRedemptionFee
        );
    }

    function _setRedemptionFee(uint256 newRedemptionFee)
    public
    onlySuperOwnerMultiSig()
    {
        state.redemptionFee = newRedemptionFee;
    }

    function setRedemptionFeeReceiverWallet(
        address newRedemptionFeeReceiverWallet
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setRedemptionFeeReceiverWallet(
            this._setRedemptionFeeReceiverWallet.selector,
            newRedemptionFeeReceiverWallet
        );
    }

    function _setRedemptionFeeReceiverWallet(
        address newRedemptionFeeReceiverWallet
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.redemptionFeeReceiverWallet = newRedemptionFeeReceiverWallet;
    }

    function setSuperOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setSuperOwnerActionCountdown(
            this._setSuperOwnerActionCountdown.selector,
            newCountdown
        );
    }

    function _setSuperOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.superOwnerActionCountdown = newCountdown;
    }

    function setBasicOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setBasicOwnerActionCountdown(
            this._setBasicOwnerActionCountdown.selector,
            newCountdown
        );
    }

    function _setBasicOwnerActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.basicOwnerActionCountdown = newCountdown;
    }

    function setWhitelistRemovalActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setWhitelistRemovalActionCountdown(
            this._setWhitelistRemovalActionCountdown.selector,
            newCountdown
        );
    }

    function _setWhitelistRemovalActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.whitelistRemovalActionCountdown = newCountdown;
    }

    function setMintingActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setMintingActionCountdown(
            this._setMintingActionCountdown.selector,
            newCountdown
        );
    }

    function _setMintingActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.mintingActionCountdown = newCountdown;
    }

    function setBurningActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setBurningActionCountdown(
            this._setBurningActionCountdown.selector,
            newCountdown
        );
    }

    function _setBurningActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.burningActionCountdown = newCountdown;
    }

    function setMintingReceiverWallet(
        address newMintingReceiverWallet
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.setMintingReceiverWallet(
            this._setMintingReceiverWallet.selector,
            newMintingReceiverWallet
        );
    }

    function _setMintingReceiverWallet(
        address newMintingReceiverWallet
    )
    public
    onlySuperOwnerMultiSig()
    {
        state.mintingReceiverWallet = newMintingReceiverWallet;
    }

    function addSuperOwner(
        address newSuperOwner
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.addSuperOwner(
            this._addSuperOwner.selector,
            newSuperOwner
        );
    }

    function _addSuperOwner(
        address newSuperOwner
    )
    public
    onlySuperOwnerMultiSig()
    {
        superOwnerRole.superOwnerMultiSig.addOwner(newSuperOwner);
        _updateSuperOwnerRequirement();
        emit LogSuperOwnerAdded(newSuperOwner);
    }

    function removeSuperOwner(
        address superOwner
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.removeSuperOwner(
            this._removeSuperOwner.selector,
            superOwner
        );
    }

    function _removeSuperOwner(
        address superOwner
    )
    public
    onlySuperOwnerMultiSig()
    {
        superOwnerRole.superOwnerMultiSig.removeOwner(superOwner);
        _updateSuperOwnerRequirement();
        emit LogSuperOwnerRemoved(superOwner);
    }

    function addBasicOwner(
        address newBasicOwner
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.removeSuperOwner(
            this._addBasicOwner.selector,
            newBasicOwner
        );
    }

    function _addBasicOwner(
        address newBasicOwner
    )
    public
    onlySuperOwnerMultiSig()
    {
        basicOwnerRole.basicOwnerMultiSig.addOwner(newBasicOwner);
        _updateBasicOwnerRequirement();
        emit LogBasicOwnerAdded(newBasicOwner);
    }

    function removeBasicOwner(
        address basicOwner
    )
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        return superOwnerRole.removeSuperOwner(
            this._removeBasicOwner.selector,
            basicOwner
        );
    }

    function _removeBasicOwner(
        address basicOwner
    )
    public
    onlySuperOwnerMultiSig()
    {
        basicOwnerRole.basicOwnerMultiSig.removeOwner(basicOwner);
        _updateBasicOwnerRequirement();
        emit LogBasicOwnerRemoved(basicOwner);
    }

    function addOperationAdmin(
        address newOperationAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.addOperationAdmin(
            this._addOperationAdmin.selector,
            newOperationAdmin
        );
    }

    function _addOperationAdmin(
        address newOperationAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        operationAdminRole.operationAdminMultiSig.addOwner(newOperationAdmin);
        _updateOperationAdminRequirement();
        emit LogOperationAdminAdded(newOperationAdmin);
    }

    function removeOperationAdmin(
        address operationAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.removeOperationAdmin(
            this._removeOperationAdmin.selector,
            operationAdmin
        );
    }

    function _removeOperationAdmin(
        address operationAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        operationAdminRole.operationAdminMultiSig.removeOwner(operationAdmin);
        _updateOperationAdminRequirement();
        emit LogOperationAdminRemoved(operationAdmin);
    }

    function addMintingAdmin(
        address newMintingAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.addMintingAdmin(
            this._addMintingAdmin.selector,
            newMintingAdmin
        );
    }

    function _addMintingAdmin(
        address newMintingAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        mintingAdminRole.mintingAdminMultiSig.addOwner(newMintingAdmin);
        _updateMintingAdminRequirement();
        emit LogMintingAdminAdded(newMintingAdmin);
    }

    function removeMintingAdmin(
        address mintingAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.removeMintingAdmin(
            this._removeMintingAdmin.selector,
            mintingAdmin
        );
    }

    function _removeMintingAdmin(
        address mintingAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        mintingAdminRole.mintingAdminMultiSig.removeOwner(mintingAdmin);
        _updateMintingAdminRequirement();
        emit LogMintingAdminRemoved(mintingAdmin);
    }

    function addRedemptionAdmin(
        address newRedemptionAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.addRedemptionAdmin(
            this._addRedemptionAdmin.selector,
            newRedemptionAdmin
        );
    }

    function _addRedemptionAdmin(
        address newRedemptionAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        redemptionAdminRole.redemptionAdminMultiSig.addOwner(newRedemptionAdmin);
        _updateRedemptionAdminRequirement();
        emit LogRedemptionAdminAdded(newRedemptionAdmin);
    }

    function removeRedemptionAdmin(
        address redemptionAdmin
    )
    public
    onlyBasicOwner()
    returns(uint256 transactionId) {
        return basicOwnerRole.removeRedemptionAdmin(
            this._removeRedemptionAdmin.selector,
            redemptionAdmin
        );
    }

    function _removeRedemptionAdmin(
        address redemptionAdmin
    )
    public
    onlyBasicOwnerMultiSig()
    {
        redemptionAdminRole.redemptionAdminMultiSig.removeOwner(redemptionAdmin);
        _updateRedemptionAdminRequirement();
        emit LogRedemptionAdminRemoved(redemptionAdmin);
    }

    function _updateSuperOwnerRequirement()
    internal
    onlySuperOwnerMultiSig() {
        _updateRequirement(superOwnerRole.superOwnerMultiSig, state.superOwnerActionThresholdPercent);
    }

    function _updateBasicOwnerRequirement()
    internal
    onlySuperOwnerMultiSig() {
        _updateRequirement(basicOwnerRole.basicOwnerMultiSig, state.basicOwnerActionThresholdPercent);
    }

    function _updateOperationAdminRequirement()
    internal
    onlyBasicOwnerMultiSig() {
        _updateRequirement(operationAdminRole.operationAdminMultiSig, state.operationAdminActionThresholdPercent);
    }

    function _updateMintingAdminRequirement()
    internal
    onlyBasicOwnerMultiSig() {
        _updateRequirement(mintingAdminRole.mintingAdminMultiSig, state.mintingAdminActionThresholdPercent);
    }

    function _updateRedemptionAdminRequirement()
    internal
    onlyBasicOwnerMultiSig() {
        _updateRequirement(redemptionAdminRole.redemptionAdminMultiSig, state.redemptionAdminActionThresholdPercent);
    }

    // updateRequirements updates the requirement property in the multsig.
    // The value is calculate post addition/removal of owner and based on
    // the threshold value for that multisig set by MPV.
    function _updateRequirement(
        IMultiSigWallet multiSig,
        uint256 threshold
    )
    internal {
        uint256 totalOwners = multiSig.getOwners().length;
        uint256 votesRequired = (
            threshold.mul(totalOwners)
        ).div(100);

        if (votesRequired == 0) {
            votesRequired = 1;
        }

        multiSig.changeRequirement(votesRequired);
    }

    function isSuperOwner(address superOwner)
    public
    returns (bool) {
        return _isOwner(superOwnerRole.superOwnerMultiSig, superOwner);
    }

    function isBasicOwner(address basicOwner)
    public
    returns (bool) {
        return _isOwner(basicOwnerRole.basicOwnerMultiSig, basicOwner);
    }

    function isOperationAdmin(address operationAdmin)
    public
    returns (bool) {
        return _isOwner(operationAdminRole.operationAdminMultiSig, operationAdmin);
    }

    function isMintingAdmin(address mintingAdmin)
    public
    returns (bool) {
        return _isOwner(mintingAdminRole.mintingAdminMultiSig, mintingAdmin);
    }

    function isRedemptionAdmin(address redemptionAdmin)
    public
    returns (bool) {
        return _isOwner(redemptionAdminRole.redemptionAdminMultiSig, redemptionAdmin);
    }

    function _isOwner(IMultiSigWallet multiSig, address owner)
    internal
    returns (bool) {
        return multiSig.hasOwner(owner);
    }

    // getSuperOwners returns super owners
    function getSuperOwners()
    public
    returns (address[] memory) {
        return _getOwners(superOwnerRole.superOwnerMultiSig);
    }

    function getBasicOwners()
    public
    returns (address[] memory) {
        return _getOwners(basicOwnerRole.basicOwnerMultiSig);
    }

    function getOperationAdmins()
    public
    returns (address[] memory) {
        return _getOwners(operationAdminRole.operationAdminMultiSig);
    }

    function getMintingAdmins()
    public
    returns (address[] memory) {
        return _getOwners(mintingAdminRole.mintingAdminMultiSig);
    }

    function getRedemptionAdmins()
    public
    returns (address[] memory) {
        return _getOwners(redemptionAdminRole.redemptionAdminMultiSig);
    }

    function _getOwners(IMultiSigWallet multiSig)
    internal
    returns (address[] memory) {
        return multiSig.getOwners();
    }

    function addAsset(MPVState.Asset memory _asset)
    public
    onlyMintingAdmin()
    returns (uint256) {
        state.pendingAssets.push(_asset);

        if (state.pendingAssetsTransactionId == 0) {
            bytes memory data = abi.encodeWithSelector(
                this._addAssets.selector
            );

            uint256 transactionId = mintingAdminRole.mintingAdminMultiSig.mpvSubmitTransaction(address(this), 0, data);
            state.pendingAssetsTransactionId = transactionId;
            return transactionId;
        } else {
            mintingAdminRole.mintingAdminMultiSig.revokeAllConfirmations(state.pendingAssetsTransactionId);
            return state.pendingAssetsTransactionId;
        }
    }

    function addAssets(MPVState.Asset[] memory _assets)
    public
    onlyMintingAdmin()
    returns (uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            addAsset(_assets[i]);
        }

        return state.pendingAssetsTransactionId;
    }

    function _addAssets()
    onlyMintingAdminMultiSig()
    public {
        enlistPendingAssets(state.pendingAssets);
        state.pendingAssetsTransactionId = 0;
        delete state.pendingAssets;
    }

    function _enlistPendingAsset(MPVState.Asset memory _asset)
    internal {
        Assets.Asset memory asset;
        asset.id = _asset.id;
        asset.valuation = _asset.valuation;
        asset.fingerprint = _asset.fingerprint;
        asset.tokens = _asset.tokens;
        asset.status = Assets.Status.ENLISTED;
        asset.timestamp = now;
        state.assets.add(asset);
        emit LogAddAsset(asset.id);
    }

    // addAssets adds a list of assets
    function enlistPendingAssets(MPVState.Asset[] memory _assets)
    internal {
        for (uint256 i = 0; i < _assets.length; i++) {
            _enlistPendingAsset(_assets[i]);
        }
    }

    function removePendingAsset(uint256 assetId)
    public
    onlyMintingAdmin()
    {
        for (uint256 i = 0; i < state.pendingAssets.length; i++) {
            if (state.pendingAssets[i].id == assetId) {
                _removePendingAssetArrayItem(i);
            }
        }

        mintingAdminRole.mintingAdminMultiSig.revokeAllConfirmations(state.pendingAssetsTransactionId);
    }

    function _removePendingAssetArrayItem(uint256 index)
    internal {
        if (index >= state.pendingAssets.length) return;

        for (uint256 i = index; i < state.pendingAssets.length-1; i++) {
            state.pendingAssets[i] = state.pendingAssets[i+1];
        }

        delete state.pendingAssets[state.pendingAssets.length-1];
        state.pendingAssets.length--;
    }

    // getAsset returns asset
    function getAsset(uint256 id)
    public
    returns (Assets.Asset memory) {
        return state.assets.get(id);
    }

    function pendingAssetsCount()
    public
    view
    returns (uint256) {
        return state.pendingAssets.length;
    }

    function pauseContract()
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._pause.selector
        );

        transactionId = _submitTransaction(superOwnerRole.superOwnerMultiSig, data);
    }

    function _pause()
    public
    onlySuperOwnerMultiSig()
    {
        super.pause();
    }

    function unpauseContract()
    public
    onlySuperOwner()
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._unpause.selector
        );

        transactionId = _submitTransaction(superOwnerRole.superOwnerMultiSig, data);
    }

    function _unpause()
    public
    onlySuperOwnerMultiSig()
    {
        super.unpause();
    }

    function _submitTransaction(IMultiSigWallet multiSig, bytes memory data)
    public
    returns (uint256 transactionId)
    {
        transactionId = multiSig.mpvSubmitTransaction(address(this), 0, data);
    }

    function dailyTransferLimit() public view returns(uint256) {
        return state.dailyTransferLimit;
    }

    function superOwnerActionThresholdPercent() public view returns(uint256) {
        return state.superOwnerActionThresholdPercent;
    }

    function redemptionFee() public view returns(uint256) {
        return state.redemptionFee;
    }

    function pendingAssets() public view returns(MPVState.Asset[] memory) {
        return state.pendingAssets;
    }

    function pendingAssetsTransactionId() public view returns(uint256) {
        return state.pendingAssetsTransactionId;
    }
}
