pragma solidity ^0.5.1;

import "./BaseMultiSigWallet/BaseMultiSigWallet.sol";


contract AdministeredMultiSigWallet is BaseMultiSigWallet {
    /// admin is the account or multisig able to submit transaction on
    /// behalf of this multisig.
    address public admin;

    /// transactor is a smart contract address able to only add transactions
    /// to retrieve a transaction id and able to revoke all confirmations too.
    /// The transactor is not an owner and cannot confirm transactions.
    /// An example for this existing is when the minting admin role contract
    /// needs to add a multisig transaction to retrieve a trasaction id so that
    /// minting admin' can begin to vote on it. We require a transaction id in
    /// in this case immediately rather than requiring the multisig to submit
    // the transaction because it would require majority vote which is not what
    /// we want in this case.
    address public transactor;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }

    modifier onlyTransactor() {
        require(transactor == msg.sender);
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

    function setTransactor(address _transactor)
    public
    onlyAdmin
    {
        transactor = _transactor;
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
        if (owners.length == 1 && isOwner[owner]) {
            revert("Cannot remove last owner");
        }

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
    onlyTransactor
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
    onlyTransactor
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
