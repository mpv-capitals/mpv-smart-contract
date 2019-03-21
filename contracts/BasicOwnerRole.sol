pragma solidity >=0.4.21 <0.6.0;

import "./IMultiSigWallet.sol";


library BasicOwnerRole {
    event LogAddOperationAdmin(uint256 transactionId, address operationAdmin);
    event LogRemoveOperationAdmin(uint256 transactionId, address operationAdmin);

    event LogAddMintingAdmin(uint256 transactionId, address mintingAdmin);
    event LogRemoveMintingAdmin(uint256 transactionId, address mintingAdmin);

    event LogAddRedemptionAdmin(uint256 transactionId, address redemptionAdmin);
    event LogRemoveRedemptionAdmin(uint256 transactionId, address redemptionAdmin);

    struct State {
        IMultiSigWallet basicOwnerMultiSig;
    }

    modifier onlyBasicOwner(State storage state) {
        require(state.basicOwnerMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicOwnerMultiSig(State storage state) {
        require(msg.sender == address(state.basicOwnerMultiSig));
        _;
    }

    function addOperationAdmin(
        State storage state,
        bytes4 selector,
        address newOperationAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            newOperationAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogAddOperationAdmin(transactionId, newOperationAdmin);
    }

    function removeOperationAdmin(
        State storage state,
        bytes4 selector,
        address operationAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            operationAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogRemoveOperationAdmin(transactionId, operationAdmin);
    }

    function addMintingAdmin(
        State storage state,
        bytes4 selector,
        address newMintingAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            newMintingAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogAddMintingAdmin(transactionId, newMintingAdmin);
    }

    function removeMintingAdmin(
        State storage state,
        bytes4 selector,
        address mintingAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            mintingAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogRemoveMintingAdmin(transactionId, mintingAdmin);
    }

    function addRedemptionAdmin(
        State storage state,
        bytes4 selector,
        address newRedemptionAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            newRedemptionAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogAddRedemptionAdmin(transactionId, newRedemptionAdmin);
    }

    function removeRedemptionAdmin(
        State storage state,
        bytes4 selector,
        address redemptionAdmin
    )
    public
    onlyBasicOwner(state)
    returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            selector,
            redemptionAdmin
        );

        transactionId = _submitTransaction(
            state.basicOwnerMultiSig,
            data
        );
        emit LogRemoveRedemptionAdmin(transactionId, redemptionAdmin);
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
}
