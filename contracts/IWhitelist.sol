pragma solidity ^0.5.1;


contract IWhitelist {
    function isWhitelisted(address account) external returns(bool);
    function addWhitelisted(address account) external;
    function removeWhitelisted(address account) external;
    function renounceWhitelisted() external;
}
