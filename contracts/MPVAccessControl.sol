pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "openzeppelin-eth/contracts/access/Roles.sol";

/**
 * @title MPVAccessControl
 * @dev MPV access control contract.
 */
contract MPVAccessControl {
    using Roles for Roles.Role;

    /*
     *  Events
     */
    event RoleAdded(address indexed account, MPVRoles role);
    event RoleRemoved(address indexed account, MPVRoles role);

    /*
     *  Storage
     */
    enum MPVRoles {
        SuperOwner,
        BasicOwner,
        OperationAdmin,
        MintingAdmin,
        RedemptionAdmin
    }

    mapping(uint => Roles.Role) private _roles;

    /*
     *  Modifiers
     */
    /// @dev Requires sender to be the desired role type.
    modifier onlyRole(MPVRoles role) {
        require(isRole(role, msg.sender), "invalid role");
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial roles.
    constructor() internal {
        _addRole(MPVRoles.SuperOwner, msg.sender);
        _addRole(MPVRoles.BasicOwner, msg.sender);
        _addRole(MPVRoles.OperationAdmin, msg.sender);
        _addRole(MPVRoles.MintingAdmin, msg.sender);
        _addRole(MPVRoles.RedemptionAdmin, msg.sender);
    }

    /// @dev Returns true if the account is the desired role type. Anyone can call
    /// this function.
    /// @param role Role type.
    /// @param account Account address.
    /// @return Returns boolean.
    function isRole(MPVRoles role, address account)
    public
    view
    returns (bool) {
        return _roles[uint(role)].has(account);
    }

    /// @dev Add a new account associated with the role type. Transaction has
    /// to be sent by a role type account.
    /// @param role Role type.
    /// @param account Account address.
    function addRole(MPVRoles role, address account)
    public
    onlyRole(role) {
        _addRole(role, account);
    }

    /// @dev Remove yourself from being associated with the role type. Transaction
    /// can be sent by anyone.
    /// @param role Role type.
    function renounceRole(MPVRoles role)
    public {
        _removeRole(role, msg.sender);
    }

    /*
     * Internal functions
     */
    /// @dev Add a new account associated with the role type.
    /// @param role Role type.
    /// @param account Account address.
    function _addRole(MPVRoles role, address account)
    internal {
        _roles[uint(role)].add(account);
        emit RoleAdded(account, role);
    }

    /// @dev Remove an account associated with the role type.
    /// @param role Role type.
    /// @param account Account address.
    function _removeRole(MPVRoles role, address account)
    internal {
        _roles[uint(role)].remove(account);
        emit RoleRemoved(account, role);
    }
}
