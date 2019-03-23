pragma solidity >=0.4.21 <0.6.0;

import "./IMultiSigWallet.sol";


library SuperOwnerRole {
    event LogAddSuperOwner(uint256 transactionId, address superOwner);
    event LogRemoveSuperOwner(uint256 transactionId, address superOwner);

    event LogAddBasicOwner(uint256 transactionId, address basicOwner);
    event LogRemoveBasicOwner(uint256 transactionId, address basicOwner);

    event LogAddOperationAdmin(uint256 transactionId, address operationAdmin);
    event LogRemoveOperationAdmin(uint256 transactionId, address operationAdmin);

    event LogAddMintingAdmin(uint256 transactionId, address mintingAdmin);
    event LogRemoveMintingAdmin(uint256 transactionId, address mintingAdmin);

    event LogAddRedemptionAdmin(uint256 transactionId, address redemptionAdmin);
    event LogRemoveRedemptionAdmin(uint256 transactionId, address redemptionAdmin);

    event LogAddAsset(uint256 assetId);
    event LogRemoveAsset(uint256 assetId);

    enum Roles {
        SuperOwner,
        BasicOwner,
        OperationAdmin,
        MintingAdmin,
        RedemptionAdmin
    }

    struct State {
        IMultiSigWallet superOwnerMultiSig;
    }

    modifier onlySuperOwner(State storage state) {
        require(state.superOwnerMultiSig.hasOwner(msg.sender));
        _;
    }

    function setSuperOwnerActionThresholdPercent(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newThreshold
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newThreshold
        );
    }

    function setRedemptionFee(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newRedemptionFee
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newRedemptionFee
        );
    }

    function setRedemptionFeeReceiverWallet(
        State storage state,
        bytes4 selector,
        uint256 action,
        address newRedemptionFeeReceiverWallet
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithAddressData(
            state.superOwnerMultiSig,
            selector,
            action,
            newRedemptionFeeReceiverWallet
        );
    }

    function setSuperOwnerActionCountdown(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newCountdown
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newCountdown
        );
    }

    function setBasicOwnerActionCountdown(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newCountdown
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newCountdown
        );
    }

    function setWhitelistRemovalActionCountdown(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newCountdown
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newCountdown
        );
    }

    function setMintingActionCountdown(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newCountdown
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newCountdown
        );
    }

    function setBurningActionCountdown(
        State storage state,
        bytes4 selector,
        uint256 action,
        uint256 newCountdown
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithUint256Data(
            state.superOwnerMultiSig,
            selector,
            action,
            newCountdown
        );
    }

    function setMintingReceiverWallet(
        State storage state,
        bytes4 selector,
        uint256 action,
        address newMintingReceiverWallet
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        return _submitTransactionWithAddressData(
            state.superOwnerMultiSig,
            selector,
            action,
            newMintingReceiverWallet
        );
    }

    function addSuperOwner(
        State storage state,
        bytes4 selector,
        address newSuperOwner
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            Roles.SuperOwner,
            Roles.SuperOwner,
            newSuperOwner
        );

        transactionId = _submitTransaction(
            state.superOwnerMultiSig,
            data
        );
        emit LogAddSuperOwner(transactionId, newSuperOwner);
    }

    function removeSuperOwner(
        State storage state,
        bytes4 selector,
        address superOwner
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            Roles.SuperOwner,
            Roles.SuperOwner,
            superOwner
        );

        transactionId = _submitTransaction(
            state.superOwnerMultiSig,
            data
        );
        emit LogRemoveSuperOwner(transactionId, superOwner);
    }

    function addBasicOwner(
        State storage state,
        bytes4 selector,
        address newBasicOwner
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            Roles.SuperOwner,
            Roles.BasicOwner,
            newBasicOwner
        );

        transactionId = _submitTransaction(
            state.superOwnerMultiSig,
            data
        );
        emit LogAddBasicOwner(transactionId, newBasicOwner);
    }

    function removeBasicOwner(
        State storage state,
        bytes4 selector,
        address basicOwner
    )
    public
    onlySuperOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            Roles.SuperOwner,
            Roles.BasicOwner,
            basicOwner
        );

        transactionId = _submitTransaction(
            state.superOwnerMultiSig,
            data
        );
        emit LogRemoveBasicOwner(transactionId, basicOwner);
    }

    function _submitTransaction(
        IMultiSigWallet multiSig,
        bytes memory data
    )
    public
    returns (uint256 transactionId)
    {
        transactionId = multiSig.mpvSubmitTransaction(address(this), 0, data);
    }

    function _submitTransactionWithAddressData(
        IMultiSigWallet multiSig,
        bytes4 selector,
        uint256 action,
        address addr
    ) public returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            action,
            addr
        );

        return _submitTransaction(multiSig, data);
    }

    function _submitTransactionWithUint256Data(
        IMultiSigWallet multiSig,
        bytes4 selector,
        uint256 action,
        uint256 value
    ) public returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            action,
            value
        );

        return _submitTransaction(multiSig, data);
    }
}
