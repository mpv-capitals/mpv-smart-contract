pragma solidity ^0.5.1;

import "./BaseMultiSigWallet/BaseMultiSigWallet.sol";


contract AdministeredMultiSigWallet is BaseMultiSigWallet {
    address public admin;
    address public mpv;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }

    constructor(address[] memory _owners, uint _required)
    public
    BaseMultiSigWallet(_owners, _required)
    {
        admin = msg.sender;
    }

    function setAdmin(address _admin)
    public
    onlyAdmin
    {
        admin = _admin;
    }

    function setMPV(address _mpv)
    public
    onlyAdmin
    {
        mpv = _mpv;
    }

    function addOwner(address owner)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.addOwner(owner);
    }

    function removeOwner(address owner)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.removeOwner(owner);
    }

    function replaceOwner(address owner, address newOwner)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.replaceOwner(owner, newOwner);
    }

    function changeRequirement(uint _required)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.changeRequirement(_required);
    }

    function addTransaction(address destination, bytes memory data)
    public
    returns (uint transactionId)
    {
        return addTransaction(destination, 0, data);
    }

    function confirmTransaction(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.confirmTransaction(transactionId);
    }

    function revokeConfirmation(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.revokeConfirmation(transactionId);
    }

    function revokeAllConfirmations(uint256 transactionId)
    public
    {
        for (uint256 i=0; i < owners.length; i++) {
            confirmations[transactionId][owners[i]] = false;
        }
    }

    function executeTransaction(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.executeTransaction(transactionId);
    }
}
