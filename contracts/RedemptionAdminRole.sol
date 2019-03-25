pragma solidity >=0.4.21 <0.6.0;

import "./IMultiSigWallet.sol";


library RedemptionAdminRole {
    struct State {
        IMultiSigWallet redemptionAdminMultiSig;
    }

    modifier onlyRedemptionAdmin(State storage state) {
        require(state.redemptionAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyRedemptionAdminMultiSig(State storage state) {
        require(msg.sender == address(state.redemptionAdminMultiSig));
        _;
    }
}
