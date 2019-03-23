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

    event LogOwnerAdded(Roles role, address superOwner);
    event LogOwnerRemoved(Roles role, address superOwner);

    event LogAddAsset(uint256 assetId);
    event LogRemoveAsset(uint256 assetId);

    enum Roles {
        SuperOwner,
        BasicOwner,
        OperationAdmin,
        MintingAdmin,
        RedemptionAdmin
    }

    enum Actions {
        setSuperOwnerActionThresholdPercent,
        setRedemptionFee,
        setRedemptionFeeReceiverWallet,
        setSuperOwnerActionCountdown,
        setBasicOwnerActionCountdown,
        setWhitelistRemovalActionCountdown,
        setMintingActionCountdown,
        setBurningActionCountdown,
        setMintingReceiverWallet,
        addOwner,
        removeOwner
    }

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

    modifier onlyRole(Roles role) {
        if (role == Roles.SuperOwner) {
            require(_isOwner(superOwnerRole.superOwnerMultiSig, msg.sender));
        } else if (role == Roles.BasicOwner) {
            require(_isOwner(basicOwnerRole.basicOwnerMultiSig, msg.sender));
        } else if (role == Roles.OperationAdmin) {
            //
        } else if (role == Roles.MintingAdmin) {
            require(_isOwner(operationAdminRole.operationAdminMultiSig, msg.sender));
        } else if (role == Roles.RedemptionAdmin) {
            //
        } else {
            revert("invalid role");
        }
        _;
    }

    modifier onlyMultiSig(Roles role) {
        require(_isMultiSig(role));
        _;
    }

    function _isMultiSig(Roles role) internal returns(bool) {
        if (role == Roles.SuperOwner) {
            return msg.sender == address(superOwnerRole.superOwnerMultiSig);
        } else if (role == Roles.BasicOwner) {
            return msg.sender == address(basicOwnerRole.basicOwnerMultiSig);
        } else if (role == Roles.MintingAdmin) {
            return msg.sender == address(mintingAdminRole.mintingAdminMultiSig);
        }
        return false;
    }

    function performAction(
        Actions action,
        Roles role,
        uint256[] memory argsUint256,
        address[] memory argsAddress
    )
    public
    returns (uint256)
    {
        if (action == Actions.setSuperOwnerActionThresholdPercent) {
            return superOwnerRole.setSuperOwnerActionThresholdPercent(
                this._callback.selector,
                uint256(Actions.setSuperOwnerActionThresholdPercent),

                argsUint256[0] // newThreshold
            );
        } else if (action == Actions.setRedemptionFee) {
            return superOwnerRole.setRedemptionFee(
                this._callback.selector,
                uint256(Actions.setRedemptionFee),
                argsUint256[0] // newRedemptionFee
            );
        } else if (action == Actions.setRedemptionFeeReceiverWallet) {
            return superOwnerRole.setRedemptionFeeReceiverWallet(
                this._callback.selector,
                uint256(Actions.setRedemptionFeeReceiverWallet),
                argsAddress[0] // newRedemptionFeeReceiverWallet
            );
        } else if (action == Actions.setSuperOwnerActionCountdown) {
                return superOwnerRole.setSuperOwnerActionCountdown(
                    this._callback.selector,
                    uint256(Actions.setSuperOwnerActionCountdown),
                    argsUint256[0] // newCountdown
                );
        } else if (action == Actions.setBasicOwnerActionCountdown) {
            return superOwnerRole.setBasicOwnerActionCountdown(
                this._callback.selector,
                uint256(Actions.setBasicOwnerActionCountdown),
                argsUint256[0] // newCountdown
            );
        } else if (action == Actions.setWhitelistRemovalActionCountdown) {
            return superOwnerRole.setWhitelistRemovalActionCountdown(
                this._callback.selector,
                uint256(Actions.setWhitelistRemovalActionCountdown),
                argsUint256[0] // newCountdown
            );
        } else if (action == Actions.setMintingActionCountdown) {
                return superOwnerRole.setMintingActionCountdown(
                    this._callback.selector,
                    uint256(Actions.setMintingActionCountdown),
                    argsUint256[0] // newCountdown
                );
        } else if (action == Actions.setBurningActionCountdown) {
                return superOwnerRole.setBurningActionCountdown(
                    this._callback.selector,
                    uint256(Actions.setBurningActionCountdown),
                    argsUint256[0] // newCountdown
                );
        } else if (action == Actions.setMintingReceiverWallet) {
                return superOwnerRole.setMintingReceiverWallet(
                    this._callback.selector,
                    uint256(Actions.setMintingReceiverWallet),
                    argsAddress[0] // newMintingReceiverWallet
                );
        } else if (action == Actions.addOwner) {
            if (role == Roles.SuperOwner) {
                return superOwnerRole.addSuperOwner(
                    this._addOwner.selector,
                    argsAddress[0] // newSuperOwner
                );
            } else if (role == Roles.BasicOwner) {
                return superOwnerRole.addBasicOwner(
                    this._addOwner.selector,
                    argsAddress[0] // newBasicOwner
                );
            } else if (role == Roles.OperationAdmin) {
                return basicOwnerRole.addOperationAdmin(
                    this._addOwner.selector,
                    argsAddress[0] // newOperationAdmin
                );
            } else if (role == Roles.MintingAdmin) {
                return basicOwnerRole.addMintingAdmin(
                    this._addOwner.selector,
                    argsAddress[0] // newMintingAdmin
                );
            } else if (role == Roles.RedemptionAdmin) {
                return basicOwnerRole.addRedemptionAdmin(
                    this._addOwner.selector,
                    argsAddress[0] // newRedemptionAdmin
                );
            }
        } else if (action == Actions.removeOwner) {
            if (role == Roles.SuperOwner) {
                return superOwnerRole.removeSuperOwner(
                    this._removeOwner.selector,
                    argsAddress[0] // basicOwner
                );
            } else if (role == Roles.BasicOwner) {
                return superOwnerRole.removeBasicOwner(
                    this._removeOwner.selector,
                    argsAddress[0] // basicOwner
                );
            } else if (role == Roles.OperationAdmin) {
                return basicOwnerRole.removeOperationAdmin(
                    this._removeOwner.selector,
                    argsAddress[0] // operationAdmin
                );
            } else if (role == Roles.MintingAdmin) {
                return basicOwnerRole.removeMintingAdmin(
                    this._removeOwner.selector,
                    argsAddress[0] // mintingAdmin
                );
            } else if (role == Roles.RedemptionAdmin) {
                return basicOwnerRole.removeRedemptionAdmin(
                    this._removeOwner.selector,
                    argsAddress[0] // redemptionAdmin
                );
            }
        }

       return 0;
    }

    function _callback(
        Actions action,
        uint256 argUint256
    )
    onlyMultiSig(Roles.SuperOwner)
    public {
        if (action == Actions.setSuperOwnerActionThresholdPercent) {
            state.superOwnerActionThresholdPercent = argUint256; // newThreshold
            _updateSuperOwnerRequirement();
        } else if (action == Actions.setRedemptionFee) {
            state.redemptionFee = argUint256; // newRedemptionFee;
        } else if (action == Actions.setRedemptionFeeReceiverWallet) {
            state.redemptionFeeReceiverWallet = address(argUint256); //newRedemptionFeeReceiverWallet;
        } else if (action == Actions.setSuperOwnerActionCountdown) {
            state.superOwnerActionCountdown = argUint256; // newCountdown
        } else if (action == Actions.setBasicOwnerActionCountdown) {
            state.basicOwnerActionCountdown = argUint256; // newCountdown
        } else if (action == Actions.setWhitelistRemovalActionCountdown) {
            //state.whitelistRemovalActionCountdown = newCountdown;
        } else if (action == Actions.setMintingActionCountdown) {
            state.mintingActionCountdown = argUint256; // newCountdown
        } else if (action == Actions.setBurningActionCountdown) {
            state.burningActionCountdown = argUint256; // newCountdown;
        } else if (action == Actions.setMintingReceiverWallet) {
            state.mintingReceiverWallet = address(argUint256); // newMintingReceiverWallet;
        }
    }

    function _addOwner(
        Roles authRole,
        Roles role,
        address owner
    )
    public
    onlyMultiSig(authRole)
    {
        if (role == Roles.SuperOwner) {
            superOwnerRole.superOwnerMultiSig.addOwner(owner);
            _updateSuperOwnerRequirement();
        } else if (role == Roles.BasicOwner) {
            basicOwnerRole.basicOwnerMultiSig.addOwner(owner);
            _updateBasicOwnerRequirement();
        } else if (role == Roles.OperationAdmin) {
            operationAdminRole.operationAdminMultiSig.addOwner(owner);
            _updateOperationAdminRequirement();
        } else if (role == Roles.MintingAdmin) {
            mintingAdminRole.mintingAdminMultiSig.addOwner(owner);
            _updateMintingAdminRequirement();
        } else if (role == Roles.RedemptionAdmin) {
            redemptionAdminRole.redemptionAdminMultiSig.addOwner(owner);
            _updateRedemptionAdminRequirement();
        }
        emit LogOwnerAdded(role, owner);
    }

    function _removeOwner(
        Roles authRole,
        Roles role,
        address owner
    )
    public
    onlyMultiSig(authRole)
    {
        if (role == Roles.SuperOwner) {
            superOwnerRole.superOwnerMultiSig.removeOwner(owner);
            _updateSuperOwnerRequirement();
        } else if (role == Roles.BasicOwner) {
            basicOwnerRole.basicOwnerMultiSig.removeOwner(owner);
            _updateBasicOwnerRequirement();
        } else if (role == Roles.OperationAdmin) {
            operationAdminRole.operationAdminMultiSig.removeOwner(owner);
            _updateOperationAdminRequirement();
        } else if (role == Roles.MintingAdmin) {
            mintingAdminRole.mintingAdminMultiSig.removeOwner(owner);
            _updateMintingAdminRequirement();
        } else if (role == Roles.RedemptionAdmin) {
            redemptionAdminRole.redemptionAdminMultiSig.removeOwner(owner);
            _updateRedemptionAdminRequirement();
        }
        emit LogOwnerAdded(role, owner);
    }

    function _updateSuperOwnerRequirement()
    internal
    onlyMultiSig(Roles.SuperOwner) {
        _updateRequirement(superOwnerRole.superOwnerMultiSig, state.superOwnerActionThresholdPercent);
    }

    function _updateBasicOwnerRequirement()
    internal
    onlyMultiSig(Roles.SuperOwner) {
        _updateRequirement(basicOwnerRole.basicOwnerMultiSig, state.basicOwnerActionThresholdPercent);
    }

    function _updateOperationAdminRequirement()
    internal
    onlyMultiSig(Roles.BasicOwner) {
        _updateRequirement(operationAdminRole.operationAdminMultiSig, state.operationAdminActionThresholdPercent);
    }

    function _updateMintingAdminRequirement()
    internal
    onlyMultiSig(Roles.BasicOwner) {
        _updateRequirement(mintingAdminRole.mintingAdminMultiSig, state.mintingAdminActionThresholdPercent);
    }

    function _updateRedemptionAdminRequirement()
    internal
    onlyMultiSig(Roles.BasicOwner) {
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

    function isOwner(Roles role, address owner)
        public
        returns (bool)
    {
        if (role == Roles.SuperOwner) {
            return _isOwner(superOwnerRole.superOwnerMultiSig, owner);
        } else if (role == Roles.BasicOwner) {
            return _isOwner(basicOwnerRole.basicOwnerMultiSig, owner);
        }  else if (role == Roles.OperationAdmin) {
            return _isOwner(operationAdminRole.operationAdminMultiSig, owner);
        } else if (role == Roles.MintingAdmin) {
            return _isOwner(mintingAdminRole.mintingAdminMultiSig, owner);
        } else if (role == Roles.RedemptionAdmin) {
            return _isOwner(redemptionAdminRole.redemptionAdminMultiSig, owner);
        }

        return false;
    }

    function _isOwner(IMultiSigWallet multiSig, address owner)
    internal
    returns (bool) {
        return multiSig.hasOwner(owner);
    }

    function getOwners(Roles role)
    public
    returns (address[] memory owners)
    {
        if (role == Roles.SuperOwner) {
            return _getOwners(superOwnerRole.superOwnerMultiSig);
        } else if (role == Roles.BasicOwner) {
            return _getOwners(basicOwnerRole.basicOwnerMultiSig);
        } else if (role == Roles.OperationAdmin) {
            return _getOwners(operationAdminRole.operationAdminMultiSig);
        } else if (role == Roles.MintingAdmin) {
            return _getOwners(mintingAdminRole.mintingAdminMultiSig);
        } else if (role == Roles.RedemptionAdmin) {
            return _getOwners(redemptionAdminRole.redemptionAdminMultiSig);
        }
    }

    function _getOwners(IMultiSigWallet multiSig)
    internal
    returns (address[] memory) {
        return multiSig.getOwners();
    }

    function addAsset(MPVState.Asset memory _asset)
    public
    onlyRole(Roles.MintingAdmin)
    returns (uint256) {
        if (!(state.pendingAssets.length > 0 || state.pendingAssetsTransactionId != 0)) {
            state.pendingAssets.push(_asset);
            bytes memory data = abi.encodeWithSelector(
                this._addAssets.selector
            );

            uint256 transactionId = mintingAdminRole.mintingAdminMultiSig.mpvSubmitTransaction(address(this), 0, data);
            state.pendingAssetsTransactionId = transactionId;
            return transactionId;
        } else {
            state.pendingAssets.push(_asset);
            mintingAdminRole.mintingAdminMultiSig.revokeAllConfirmations(state.pendingAssetsTransactionId);
            return state.pendingAssetsTransactionId;
        }
    }

    function addAssets(MPVState.Asset[] memory _assets)
    public
    onlyRole(Roles.MintingAdmin)
    returns (uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            addAsset(_assets[i]);
        }

        return state.pendingAssetsTransactionId;
    }

    function _addAssets()
    onlyMultiSig(Roles.MintingAdmin)
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
    onlyRole(Roles.MintingAdmin)
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
    onlyRole(Roles.SuperOwner)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._pause.selector
        );

        transactionId = _submitTransaction(superOwnerRole.superOwnerMultiSig, data);
    }

    function _pause()
    public
    onlyMultiSig(Roles.SuperOwner)
    {
        super.pause();
    }

    function unpauseContract()
    public
    onlyRole(Roles.SuperOwner)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._unpause.selector
        );

        transactionId = _submitTransaction(superOwnerRole.superOwnerMultiSig, data);
    }

    function _unpause()
    public
    onlyMultiSig(Roles.SuperOwner)
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

    function redemptionFeeReceiverWallet() public view returns(address) {
        return state.redemptionFeeReceiverWallet;
    }

    function pendingAssets() public view returns(MPVState.Asset[] memory) {
        return state.pendingAssets;
    }

    function pendingAssetsTransactionId() public view returns(uint256) {
        return state.pendingAssetsTransactionId;
    }
}
