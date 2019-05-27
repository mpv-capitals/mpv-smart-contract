pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/access/Roles.sol";
import "./IMultiSigWallet.sol";
import "./MasterPropertyValue.sol";


/**
 * @title Whitelist
 * @dev Whitelist for managing accounts authorized to transfer tokens.
 */
contract Whitelist is Initializable {
    using Roles for Roles.Role;
    Roles.Role private _whitelisteds;

    /*
     *  Events
     */
    event WhitelistedAdded(address indexed account);
    event WhitelistedRemoved(address indexed account);

    /*
     *  Storage
     */
    IMultiSigWallet public operationAdminMultiSig;
    IMultiSigWallet public basicProtectorMultiSig;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    /// @dev Requires sender to be the operation admin multisig contract.
    modifier onlyOperationAdmin() {
        require(operationAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    /// @dev Requires sender to be the basic owner multisig contract.
    modifier onlyBasicProtectorMultiSig() {
        require(address(basicProtectorMultiSig) == msg.sender);
        _;
    }

    /// @dev Requires sender to be whitelisted.
    modifier onlyWhitelisted() {
        require(isWhitelisted(msg.sender));
        _;
    }

    /// @dev Requires that the MPV contract is not paused.
    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Initialize function set initial storage values.
    /// @param _operationAdminMultiSig Address of operation admin multisig contract.
    /// @param _basicProtectorMultiSig Address of basic protector multisig contract.
    function initialize(
        address _operationAdminMultiSig,
        address _basicProtectorMultiSig,
        MasterPropertyValue _masterPropertyValue
    ) public initializer
    {
        operationAdminMultiSig = IMultiSigWallet(_operationAdminMultiSig);
        basicProtectorMultiSig = IMultiSigWallet(_basicProtectorMultiSig);
        masterPropertyValue = _masterPropertyValue;
    }

    /// @dev Add account to whitelist.
    /// @param account Address of account.
    function addWhitelisted(address account)
    public
    onlyOperationAdmin
    mpvNotPaused
    {
        _addWhitelisted(account);
    }

    /// @dev Add multiple accounts to whitelist.
    /// @param accounts List of account addresses.
    function addWhitelisteds(address[] memory accounts)
    public
    onlyOperationAdmin
    mpvNotPaused
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            _addWhitelisted(accounts[i]);
        }
    }

    /// @dev Remove account from whitelist.
    /// @param account Address of account.
    function removeWhitelisted(address account)
    public
    onlyBasicProtectorMultiSig
    mpvNotPaused
    {
        _removeWhitelisted(account);
    }

    /// @dev Remove multiple accounts from whitelist.
    /// @param accounts List of account addresses.
    function removeWhitelisteds(address[] memory accounts)
    public
    onlyBasicProtectorMultiSig
    mpvNotPaused
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            _removeWhitelisted(accounts[i]);
        }
    }

    /// @dev Remove sender from whitelist.
    function renounceWhitelisted()
    public
    mpvNotPaused
    {
        _removeWhitelisted(msg.sender);
    }

    /// @dev Returns true if account is whitelisted. Transaction can be sent by anyone.
    /// @param account Address of account.
    /// @return whitelisted boolean.
    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisteds.has(account);
    }

    /*
     *  Internal functions
     */
    /// @dev Add account to whitelist.
    /// @param account Address of account.
    function _addWhitelisted(address account) internal {
        _whitelisteds.add(account);
        emit WhitelistedAdded(account);
    }

    /// @dev Remove account to whitelist.
    /// @param account Address of account.
    function _removeWhitelisted(address account) internal {
        _whitelisteds.remove(account);
        emit WhitelistedRemoved(account);
    }
}
