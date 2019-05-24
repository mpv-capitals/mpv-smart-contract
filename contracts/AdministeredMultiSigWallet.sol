pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./BaseMultiSigWallet/BaseMultiSigWallet.sol";
import "./MasterPropertyValue.sol";


/**
 * @title AdministeredMultiSigWallet
 * @dev An Administered MultiSigWallet where an admin account is authorized to
 * submit transactions on behalf of the owner.
 */
contract AdministeredMultiSigWallet is BaseMultiSigWallet, Initializable {
    /*
     *  Events
     */
    event RevokeAll(address indexed sender, uint256 indexed transactionId);
    event AdminUpdated(address indexed sender, address indexed admin);
    event TransactorUpdated(address indexed sender, address indexed transactor);

    /*
     *  Storage
     */
    /// admin is the account or multisig able to submit transaction on
    /// behalf of this multisig.
    address public admin;
    MasterPropertyValue public masterPropertyValue;

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

    /*
     *  Modifiers
     */
    /// @dev Requires sender to be the admin.
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    /// @dev Requires that the sender is an owner.
    modifier ownerExists(address owner) {
        require(isOwner[owner]);
        _;
    }

    /// @dev Requires that the sender is the transactor account.
    modifier onlyTransactor() {
        require(transactor == msg.sender);
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
    /// @dev Contract initializer sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    function initialize(
        address[] memory _owners,
        uint _required
    )
    public
    validRequirement(_owners.length, _required)
    initializer {
        for (uint i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != address(0));
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
        admin = msg.sender;
    }

    /// @dev Sets an account to be the new admin. Transaction must be sent
    /// from the current admin account.
    /// @param _admin Address of new admin account.
    function updateAdmin(address _admin)
    public
    onlyAdmin
    {
        require(_admin != address(0));
        admin = _admin;
        emit AdminUpdated(msg.sender, _admin);
    }

    /// @dev Sets an account to be the new transactor account. Transaction must
    /// be sent from the current admin account.
    /// @param _transactor Address of new transactor account.
    function updateTransactor(address _transactor)
    public
    onlyAdmin
    {
        require(_transactor != address(0));
        transactor = _transactor;
        emit TransactorUpdated(msg.sender, _transactor);
    }

    /// @dev Allows to add an owner. Transaction has to be sent by admin.
    /// @param owner Address of owner.
    function addOwner(address owner)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.addOwner(owner);
    }

    /// @dev Allows to remove an owner. Transaction has to be sent by admin.
    /// @param owner Address of owner.
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

    /// @dev Allows to replace an owner with a new owner. Transaction has to be
    /// sent by admin.
    /// @param owner Address of owner to be replaced.
    /// @param newOwner Address of new owner.
    function replaceOwner(address owner, address newOwner)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.replaceOwner(owner, newOwner);
    }

    /// @dev Allows to change the number of required confirmations. Transaction
    /// has to be sent by admin.
    /// @param _required Number of required confirmations.
    function changeRequirement(uint _required)
    public
    onlyAdmin
    validRequirement(owners.length + 1, required)
    {
        super.changeRequirement(_required);
    }

    function submitTransaction(address destination, uint value, bytes memory data)
        public
        ownerExists(msg.sender)
        returns (uint transactionId)
    {
        return super.submitTransaction(destination, value, data);
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction
    /// does not exist yet. Transaction has to be sent by transactor account.
    /// @param destination Transaction target address.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, bytes memory data)
    public
    onlyTransactor
    returns (uint transactionId)
    {
        return addTransaction(destination, 0, data);
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.confirmTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.revokeConfirmation(transactionId);
    }

    /// @dev Allows the transactor admin to revoke all confirmations for a
    /// transaction id. This method is invoked when reseting confirmation votes
    /// on cancelleation actions.
    /// @param transactionId Transaction ID.
    function revokeAllConfirmations(uint256 transactionId)
    public
    onlyTransactor
    {
        for (uint256 i=0; i < owners.length; i++) {
            confirmations[transactionId][owners[i]] = false;
        }

        transactions[transactionId].executed = false;
        emit RevokeAll(msg.sender, transactionId);
    }

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId)
    public
    ownerExists(msg.sender)
    {
        super.executeTransaction(transactionId);
    }

    function isExecuted(uint transactionId)
    public
    view
    returns (bool)
    {
        return transactions[transactionId].executed;
    }
}
