pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./IMultiSigWallet.sol";
import "./IWhitelist.sol";
import "./Assets.sol";
import "./Pausable.sol";
import "./MPVState.sol";
import "./SuperOwnerRole.sol";
import "./BasicOwnerRole.sol";
import "./OperationAdminRole.sol";
import "./MintingAdminRole.sol";
import "./RedemptionAdminRole.sol";
import "./MPVToken.sol";


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
        removeOwner,
        pauseContract,
        addPendingAsset,
        removePendingAsset,
        updatePendingAssetsStatus
    }

    struct ActionArgs {
        Roles role;
        uint256[] uint256Args;
        address[] addressArgs;
        bytes32[] bytes32Args;
    }

    modifier onlyRole(Roles role) {
        if (role == Roles.SuperOwner) {
            require(_isOwner(superOwnerRole.superOwnerMultiSig, msg.sender));
        } else if (role == Roles.BasicOwner) {
            require(_isOwner(basicOwnerRole.basicOwnerMultiSig, msg.sender));
        } else if (role == Roles.OperationAdmin) {
            require(_isOwner(operationAdminRole.operationAdminMultiSig, msg.sender));
        } else if (role == Roles.MintingAdmin) {
            require(_isOwner(mintingAdminRole.mintingAdminMultiSig, msg.sender));
        } else if (role == Roles.RedemptionAdmin) {
            require(_isOwner(redemptionAdminRole.redemptionAdminMultiSig, msg.sender));
        } else {
            revert("invalid role");
        }
        _;
    }

    modifier onlyMultiSig(Roles role) {
        require(_isMultiSig(role));
        _;
    }

    modifier mintingCountownTerminated() {
        require(state.mintingCountownStart == 0);
        _;
    }

    function initialize(
        MPVToken _mpvToken,
        IMultiSigWallet _superOwnerMultiSig,
        IMultiSigWallet _basicOwnerMultiSig,
        IMultiSigWallet _operationAdminMultiSig,
        IMultiSigWallet _mintingAdminMultiSig,
        IMultiSigWallet _redemptionAdminMultiSig,
        IWhitelist _whitelist,
        address _mintingReceiverWallet,
        uint _dailyTransferLimit
    ) public initializer {
        state.mpvToken = _mpvToken;

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

        state.superOwnerActionCountdownLength = 48 hours;
        state.basicOwnerActionCountdownLength = 48 hours;
        state.whitelistRemovalActionCountdownLength = 48 hours;
        state.mintingActionCountdownLength = 48 hours;
        state.burningActionCountdownLength = 48 hours;

        // NOTE: default is 0.1 tokens
        // 1000 = 0.1 * (10 ** 4)
        state.redemptionFee = 1000;

        state.mpvToken.setMPV(address(this));
    }

    function invoke(
        Actions action,
        ActionArgs memory actionArgs
    )
    public
    returns (uint256)
    {
        if (action == Actions.setSuperOwnerActionThresholdPercent) {
            return superOwnerRole.setSuperOwnerActionThresholdPercent(
                this._callback.selector,
                uint256(Actions.setSuperOwnerActionThresholdPercent),

                actionArgs.uint256Args[0] // newThreshold
            );
        } else if (action == Actions.setRedemptionFee) {
            return superOwnerRole.setRedemptionFee(
                this._callback.selector,
                uint256(Actions.setRedemptionFee),
                actionArgs.uint256Args[0] // newRedemptionFee
            );
        } else if (action == Actions.setRedemptionFeeReceiverWallet) {
            return superOwnerRole.setRedemptionFeeReceiverWallet(
                this._callback.selector,
                uint256(Actions.setRedemptionFeeReceiverWallet),
                actionArgs.addressArgs[0] // newRedemptionFeeReceiverWallet
            );
        } else if (action == Actions.setSuperOwnerActionCountdown) {
            return superOwnerRole.setSuperOwnerActionCountdown(
                this._callback.selector,
                uint256(Actions.setSuperOwnerActionCountdown),
                actionArgs.uint256Args[0] // newCountdown
            );
        } else if (action == Actions.setBasicOwnerActionCountdown) {
            return superOwnerRole.setBasicOwnerActionCountdown(
                this._callback.selector,
                uint256(Actions.setBasicOwnerActionCountdown),
                actionArgs.uint256Args[0] // newCountdown
            );
        } else if (action == Actions.setWhitelistRemovalActionCountdown) {
            return superOwnerRole.setWhitelistRemovalActionCountdown(
                this._callback.selector,
                uint256(Actions.setWhitelistRemovalActionCountdown),
                actionArgs.uint256Args[0] // newCountdown
            );
        } else if (action == Actions.setMintingActionCountdown) {
            return superOwnerRole.setMintingActionCountdown(
                this._callback.selector,
                uint256(Actions.setMintingActionCountdown),
                actionArgs.uint256Args[0] // newCountdown
            );
        } else if (action == Actions.setBurningActionCountdown) {
            return superOwnerRole.setBurningActionCountdown(
                this._callback.selector,
                uint256(Actions.setBurningActionCountdown),
                actionArgs.uint256Args[0] // newCountdown
            );
        } else if (action == Actions.setMintingReceiverWallet) {
            return superOwnerRole.setMintingReceiverWallet(
                this._callback.selector,
                uint256(Actions.setMintingReceiverWallet),
                actionArgs.addressArgs[0] // newMintingReceiverWallet
            );
        } else if (action == Actions.addOwner) {
            if (actionArgs.role == Roles.SuperOwner) {
                return superOwnerRole.addSuperOwner(
                    this._addOwner.selector,
                    actionArgs.addressArgs[0] // newSuperOwner
                );
            } else if (actionArgs.role == Roles.BasicOwner) {
                return superOwnerRole.addBasicOwner(
                    this._addOwner.selector,
                    actionArgs.addressArgs[0] // newBasicOwner
                );
            } else if (actionArgs.role == Roles.OperationAdmin) {
                return basicOwnerRole.addOperationAdmin(
                    this._addOwner.selector,
                    actionArgs.addressArgs[0] // newOperationAdmin
                );
            } else if (actionArgs.role == Roles.MintingAdmin) {
                return basicOwnerRole.addMintingAdmin(
                    this._addOwner.selector,
                    actionArgs.addressArgs[0] // newMintingAdmin
                );
            } else if (actionArgs.role == Roles.RedemptionAdmin) {
                return basicOwnerRole.addRedemptionAdmin(
                    this._addOwner.selector,
                    actionArgs.addressArgs[0] // newRedemptionAdmin
                );
            }
        } else if (action == Actions.removeOwner) {
            if (actionArgs.role == Roles.SuperOwner) {
                return superOwnerRole.removeSuperOwner(
                    this._removeOwner.selector,
                    actionArgs.addressArgs[0] // superOwner
                );
            } else if (actionArgs.role == Roles.BasicOwner) {
                return superOwnerRole.removeBasicOwner(
                    this._removeOwner.selector,
                    actionArgs.addressArgs[0] // basicOwner
                );
            } else if (actionArgs.role == Roles.OperationAdmin) {
                return basicOwnerRole.removeOperationAdmin(
                    this._removeOwner.selector,
                    actionArgs.addressArgs[0] // operationAdmin
                );
            } else if (actionArgs.role == Roles.MintingAdmin) {
                return basicOwnerRole.removeMintingAdmin(
                    this._removeOwner.selector,
                    actionArgs.addressArgs[0] // mintingAdmin
                );
            } else if (actionArgs.role == Roles.RedemptionAdmin) {
                return basicOwnerRole.removeRedemptionAdmin(
                    this._removeOwner.selector,
                    actionArgs.addressArgs[0] // redemptionAdmin
                );
            }
        } else if (action == Actions.pauseContract) {
            return superOwnerRole.pauseContract(
                this._callback.selector,
                uint256(Actions.pauseContract),
                actionArgs.uint256Args[0] // pause boolean
            );
        } else if (action == Actions.addPendingAsset) {
            MPVState.Asset memory asset;
            asset.id = actionArgs.uint256Args[0];
            asset.notarizationId = actionArgs.bytes32Args[0];
            asset.tokens = actionArgs.uint256Args[1];

            return _addPendingAsset(asset);
        } else if (action == Actions.removePendingAsset) {
            _removePendingAsset(actionArgs.uint256Args[0]);
            return 0;
        } else if (action == Actions.updatePendingAssetsStatus) {
            require(now >= state.mintingCountownStart + state.mintingActionCountdownLength);
            _enlistPendingAssets(state.pendingAssets);
            return 0;
        }

        revert("invalid action");
        return 0;
    }

    function _callback(
        Actions action,
        uint256 arg
    )
    public
    onlyMultiSig(Roles.SuperOwner)
    {
        if (action == Actions.setSuperOwnerActionThresholdPercent) {
            state.superOwnerActionThresholdPercent = arg; // newThreshold
            _updateSuperOwnerRequirement();
        } else if (action == Actions.setRedemptionFee) {
            state.redemptionFee = arg; // newRedemptionFee;
        } else if (action == Actions.setRedemptionFeeReceiverWallet) {
            state.redemptionFeeReceiverWallet = address(arg); //newRedemptionFeeReceiverWallet;
        } else if (action == Actions.setSuperOwnerActionCountdown) {
            state.superOwnerActionCountdownLength = arg; // newCountdown
        } else if (action == Actions.setBasicOwnerActionCountdown) {
            state.basicOwnerActionCountdownLength = arg; // newCountdown
        } else if (action == Actions.setWhitelistRemovalActionCountdown) {
            state.whitelistRemovalActionCountdownLength = arg; // newCountdown;
        } else if (action == Actions.setMintingActionCountdown) {
            state.mintingActionCountdownLength = arg; // newCountdown
        } else if (action == Actions.setBurningActionCountdown) {
            state.burningActionCountdownLength = arg; // newCountdown;
        } else if (action == Actions.setMintingReceiverWallet) {
            state.mintingReceiverWallet = address(arg); // newMintingReceiverWallet;
        } else if (action == Actions.pauseContract) {
            if (arg == 1) {
                super.pause();
            } else {
                super.unpause();
            }
        }
    }

    function _addOwner(
        Roles authRole,
        Roles modifyRole,
        address owner
    )
    public
    onlyMultiSig(authRole)
    {
        if (modifyRole == Roles.SuperOwner) {
            superOwnerRole.superOwnerMultiSig.addOwner(owner);
            _updateSuperOwnerRequirement();
        } else if (modifyRole == Roles.BasicOwner) {
            basicOwnerRole.basicOwnerMultiSig.addOwner(owner);
            _updateBasicOwnerRequirement();
        } else if (modifyRole == Roles.OperationAdmin) {
            operationAdminRole.operationAdminMultiSig.addOwner(owner);
            _updateOperationAdminRequirement();
        } else if (modifyRole == Roles.MintingAdmin) {
            mintingAdminRole.mintingAdminMultiSig.addOwner(owner);
            _updateMintingAdminRequirement();
        } else if (modifyRole == Roles.RedemptionAdmin) {
            redemptionAdminRole.redemptionAdminMultiSig.addOwner(owner);
            _updateRedemptionAdminRequirement();
        }
        emit LogOwnerAdded(modifyRole, owner);
    }

    function _removeOwner(
        Roles authRole,
        Roles modifyRole,
        address owner
    )
    public
    onlyMultiSig(authRole)
    {
        if (modifyRole == Roles.SuperOwner) {
            superOwnerRole.superOwnerMultiSig.removeOwner(owner);
            _updateSuperOwnerRequirement();
        } else if (modifyRole == Roles.BasicOwner) {
            basicOwnerRole.basicOwnerMultiSig.removeOwner(owner);
            _updateBasicOwnerRequirement();
        } else if (modifyRole == Roles.OperationAdmin) {
            operationAdminRole.operationAdminMultiSig.removeOwner(owner);
            _updateOperationAdminRequirement();
        } else if (modifyRole == Roles.MintingAdmin) {
            mintingAdminRole.mintingAdminMultiSig.removeOwner(owner);
            _updateMintingAdminRequirement();
        } else if (modifyRole == Roles.RedemptionAdmin) {
            redemptionAdminRole.redemptionAdminMultiSig.removeOwner(owner);
            _updateRedemptionAdminRequirement();
        }
        emit LogOwnerAdded(modifyRole, owner);
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

    function addPendingAssets(MPVState.Asset[] memory _assets)
    public
    onlyRole(Roles.MintingAdmin)
    returns (uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            _addPendingAsset(_assets[i]);
        }

        return state.pendingAssetsTransactionId;
    }

    function _addPendingAsset(MPVState.Asset memory _asset)
    internal
    onlyRole(Roles.MintingAdmin)
    mintingCountownTerminated()
    returns (uint256) {
        if (!(state.pendingAssets.length > 0 || state.pendingAssetsTransactionId != 0)) {
            state.pendingAssets.push(_asset);
            bytes memory data = abi.encodeWithSelector(
                this._startMintingCountdown.selector
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

    function _removePendingAsset(uint256 assetId)
    internal
    onlyRole(Roles.MintingAdmin)
    {
        for (uint256 i = 0; i < state.pendingAssets.length; i++) {
            if (state.pendingAssets[i].id == assetId) {
                _removePendingAssetArrayItem(i);
            }
        }

        mintingAdminRole.mintingAdminMultiSig.revokeAllConfirmations(state.pendingAssetsTransactionId);
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

    function _startMintingCountdown()
    public
    onlyMultiSig(Roles.MintingAdmin)
    {
        state.mintingCountownStart = now;
    }

    function _submitTransaction(IMultiSigWallet multiSig, bytes memory data)
    public
    returns (uint256 transactionId)
    {
        transactionId = multiSig.mpvSubmitTransaction(address(this), 0, data);
    }

    function getOwners(
        Roles role
    )
    public
    returns (address[] memory owners) {
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

    function mintingCountownStart() public view returns(uint256) {
        return state.mintingCountownStart;
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

    function _removePendingAssetArrayItem(uint256 index)
    internal {
        if (index >= state.pendingAssets.length) return;

        for (uint256 i = index; i < state.pendingAssets.length-1; i++) {
            state.pendingAssets[i] = state.pendingAssets[i+1];
        }

        delete state.pendingAssets[state.pendingAssets.length-1];
        state.pendingAssets.length--;
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

    function _isOwner(IMultiSigWallet multiSig, address owner)
    internal
    returns (bool) {
        return multiSig.hasOwner(owner);
    }

    function _getOwners(IMultiSigWallet multiSig)
    internal
    returns (address[] memory) {
        return multiSig.getOwners();
    }

    function _resetPendingAssets()
    internal {
        state.pendingAssetsTransactionId = 0;
        delete state.pendingAssets;
        state.mintingCountownStart = 0;
    }

    function _enlistPendingAsset(MPVState.Asset memory _asset)
    internal {
        Assets.Asset memory asset;
        asset.id = _asset.id;
        asset.notarizationId = _asset.notarizationId;
        asset.tokens = _asset.tokens;
        asset.status = Assets.Status.ENLISTED;
        asset.timestamp = now;
        state.assets.add(asset);
        state.mpvToken.mint(state.mintingReceiverWallet, asset.tokens);
        emit LogAddAsset(asset.id);
    }

    function _enlistPendingAssets(MPVState.Asset[] memory _assets)
    internal {
        for (uint256 i = 0; i < _assets.length; i++) {
            _enlistPendingAsset(_assets[i]);
        }

        _resetPendingAssets();
    }

}
