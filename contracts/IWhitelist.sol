pragma solidity ^0.5.1;


contract IWhitelist {
    function isWhitelisted(address account) external returns(bool);
    function addWhitelisted(address account) external;
    function addWhitelisteds(address[] calldata accounts) external;
    function removeWhitelisted(address account) external;
    function removeWhitelisteds(address[] calldata accounts) external;
    function renounceWhitelisted() external;
}
