pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "openzeppelin-eth/contracts/access/Roles.sol";

contract MPVAccessControl {
    using Roles for Roles.Role;

    event RoleAdded(address indexed account, MPVRoles role);
    event RoleRemoved(address indexed account, MPVRoles role);

    enum MPVRoles {
        SuperOwner,
        BasicOwner,
        OperationAdmin,
        MintingAdmin,
        RedemptionAdmin
    }

    mapping(uint => Roles.Role) private _roles;

    constructor () internal {
        _addRole(MPVRoles.SuperOwner, msg.sender);
        _addRole(MPVRoles.BasicOwner, msg.sender);
        _addRole(MPVRoles.OperationAdmin, msg.sender);
        _addRole(MPVRoles.MintingAdmin, msg.sender);
        _addRole(MPVRoles.RedemptionAdmin, msg.sender);
    }

    modifier onlyRole(MPVRoles role) {
        require(isRole(role, msg.sender), "invalid role");
        _;
    }

    function isRole(MPVRoles role, address account) public view returns (bool) {
        return _roles[uint(role)].has(account);
    }

    function addRole(MPVRoles role, address account) public onlyRole(role) {
        _addRole(role, account);
    }

    function renounceRole(MPVRoles role) public {
        _removeRole(role, msg.sender);
    }

    function _addRole(MPVRoles role, address account) internal {
        _roles[uint(role)].add(account);
        emit RoleAdded(account, role);
    }

    function _removeRole(MPVRoles role, address account) internal {
        _roles[uint(role)].remove(account);
        emit RoleRemoved(account, role);
    }
}
