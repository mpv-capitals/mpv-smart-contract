pragma solidity >=0.4.21 <0.6.0;

import "./IMultiSigWallet.sol";


library MintingAdminRole {
    struct State {
        IMultiSigWallet mintingAdminMultiSig;
    }

    modifier onlyMintingAdmin(State storage state) {
        require(state.mintingAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyMintingAdminMultiSig(State storage state) {
        require(msg.sender == address(state.mintingAdminMultiSig));
        _;
    }
}
