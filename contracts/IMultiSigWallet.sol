pragma solidity >=0.4.21 <0.6.0;

interface IMultiSigWallet {
    function addOwner(address owner) external;
    function hasOwner(address owner) external returns (bool);
    function submitTransaction(address destination, uint value, bytes calldata data) external returns (uint transactionId);
    function executeTransaction(uint transactionId) external;
}
