pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/access/Roles.sol";
import "./IMultiSigWallet.sol";


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
    IMultiSigWallet public basicOwnerMultiSig;

    /*
     *  Modifiers
     */
    modifier onlyOperationAdmin() {
        require(operationAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicOwnerMultiSig() {
        require(address(basicOwnerMultiSig) == msg.sender);
        _;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted(msg.sender));
        _;
    }

    /*
     *  Public functions
     */
    function initialize(
        address _operationAdminMultiSig,
        address _basicOwnerMultiSig
    ) public initializer {
        operationAdminMultiSig = IMultiSigWallet(_operationAdminMultiSig);
        basicOwnerMultiSig = IMultiSigWallet(_basicOwnerMultiSig);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelisteds.has(account);
    }

    function addWhitelisted(address account) public onlyOperationAdmin {
        _addWhitelisted(account);
    }

    function addWhitelisteds(address[] memory accounts) public onlyOperationAdmin {
        for (uint256 i = 0; i < accounts.length; i++) {
            _addWhitelisted(accounts[i]);
        }
    }

    function removeWhitelisted(address account)
    public
    onlyBasicOwnerMultiSig {
        _removeWhitelisted(account);
    }

    function removeWhitelisteds(address[] memory accounts)
    public
    onlyBasicOwnerMultiSig {
        for (uint256 i = 0; i < accounts.length; i++) {
            _removeWhitelisted(accounts[i]);
        }
    }

    function renounceWhitelisted() public {
        _removeWhitelisted(msg.sender);
    }

    /*
     *  Internal functions
     */
    function _addWhitelisted(address account) internal {
        _whitelisteds.add(account);
        emit WhitelistedAdded(account);
    }

    function _removeWhitelisted(address account) internal {
        _whitelisteds.remove(account);
        emit WhitelistedRemoved(account);
    }
}
