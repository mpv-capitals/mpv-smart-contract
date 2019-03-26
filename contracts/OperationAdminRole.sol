pragma solidity ^0.5.1;

import "./IMultiSigWallet.sol";


library OperationAdminRole {
    struct State {
        IMultiSigWallet operationAdminMultiSig;
    }

    modifier onlyOperationAdmin(State storage state) {
        require(state.operationAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyOperationAdminMultiSig(State storage state) {
        require(msg.sender == address(state.operationAdminMultiSig));
        _;
    }
}
