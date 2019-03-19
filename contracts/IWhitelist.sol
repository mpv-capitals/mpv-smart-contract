pragma solidity >=0.4.21 <0.6.0;


contract IWhitelist {
    function isWhitelisted(address account) external returns(bool);
    function addWhitelisted(address account) external;
    function removeWhitelisted(address account) external;
    function renounceWhitelisted() external;
}
