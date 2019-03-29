pragma solidity ^0.5.1;


interface IMultiSigWallet {
    function addOwner(address owner) external;

    function removeOwner(address owner) external;

    function changeRequirement(uint _required) external;

    function confirmTransaction(uint transactionId) external;

    function submitTransaction(
        address destination,
        uint value,
        bytes calldata data
    ) external returns (uint transactionId);

    function addTransaction(address destination, bytes calldata data) external returns(uint transactionId);

    function revokeConfirmation(uint transactionId) external;

    function executeTransaction(uint transactionId) external;

    function isConfirmed(uint transactionId) external;

    function hasOwner(address owner) external returns (bool);

    function mpvSubmitTransaction(
        address destination,
        uint value,
        bytes calldata data
    ) external returns (uint transactionId);

    function getOwners() external returns (address[] memory);

    function ownerConfirmed(
        uint transactionId,
        address owner
    ) external returns (bool);

    function revokeAllConfirmations(uint transactionId) external;

    function getConfirmationCount(uint transactionId) external view returns (uint count);

}
