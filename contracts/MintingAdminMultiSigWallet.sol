pragma solidity ^0.5.1;

import "./BaseMultiSigWallet/BaseMultiSigWallet.sol";


contract MintingAdminMultiSigWallet is BaseMultiSigWallet {
    address public mpv;

    modifier onlyMPV() {
        require(msg.sender == mpv);
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }

    constructor(address[] memory _owners, uint _required)
        public
        BaseMultiSigWallet(_owners, _required)
    { }

    function setMPV(address _mpv)
        public
        ownerExists(msg.sender)
    {
        mpv = _mpv;
    }

    function addOwner(address owner)
        public
        onlyMPV()
        validRequirement(owners.length + 1, required)
    {
        super.addOwner(owner);
    }

    function removeOwner(address owner)
        public
        onlyMPV()
        validRequirement(owners.length + 1, required)
    {
        super.removeOwner(owner);
    }

    function replaceOwner(address owner, address newOwner)
        public
        onlyMPV()
        validRequirement(owners.length + 1, required)
    {
        super.replaceOwner(owner, newOwner);
    }

    function changeRequirement(uint _required)
        public
        onlyMPV()
        validRequirement(owners.length + 1, required)
    {
        super.changeRequirement(_required);
    }

    function submitTransaction(address destination, uint value, bytes memory data)
        public
        returns (uint transactionId)
    {
        return super.submitTransaction(destination, value, data);
    }

    function mpvSubmitTransaction(
        address destination,
        uint value,
        bytes memory data
    )
        public
        onlyMPV()
        returns (uint transactionId)
    {
        return addTransaction(destination, value, data);
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
        onlyMPV()
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
