pragma solidity ^0.5.1;

import "./BaseFactory.sol";
import "./BaseMultiSigWalletWithDailyLimit.sol";


/// @title Multisignature wallet factory for daily limit version - Allows creation of multisig wallet.
/// @author Stefan George - <stefan.george@consensys.net>
contract BaseMultiSigWalletWithDailyLimitFactory is BaseFactory {

    /*
     * Public functions
     */
    /// @dev Allows verified creation of multisignature wallet.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    /// @param _dailyLimit Amount in wei, which can be withdrawn without confirmations on a daily basis.
    /// @return Returns wallet address.
    function create(address[] memory _owners, uint _required, uint _dailyLimit)
        public
        returns (address wallet)
    {
        wallet = address(new BaseMultiSigWalletWithDailyLimit(_owners, _required, _dailyLimit));
        register(wallet);
    }
}
