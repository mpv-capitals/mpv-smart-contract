pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import "./Whitelist.sol";
import "./MasterPropertyValue.sol";


contract MPVToken is Initializable, ERC20, ERC20Detailed {

    Whitelist public whitelist;
    MasterPropertyValue public masterPropertyValue;
    address public mintingAdmin;
    address public redemptionAdmin;
    mapping(address => DailyLimitInfo) public dailyLimits;
    uint256 public dailyLimit;

    struct DailyLimitInfo {
        uint lastDay;
        uint spentToday;
    }

    modifier whitelistedAddress(address addr) {
        require(whitelist.isWhitelisted(addr));
        _;
    }

    modifier mpvAccessOnly(address addr) {
        require(addr == address(masterPropertyValue));
        _;
    }

    modifier onlyMintingAdmin() {
        require(mintingAdmin == msg.sender);
        _;
    }

    modifier onlyRedemptionAdmin() {
        require(mintingAdmin == msg.sender);
        _;
    }

    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        Whitelist _whitelist,
        MasterPropertyValue _masterPropertyValue,
        address _mintingAdmin,
        address _redemptionAdmin,
        uint256 _dailyLimit

    ) public initializer
    {
        ERC20Detailed.initialize(name, symbol, decimals);
        whitelist = _whitelist;
        masterPropertyValue = _masterPropertyValue;
        mintingAdmin = _mintingAdmin;
        redemptionAdmin = _redemptionAdmin;
        dailyLimit = _dailyLimit;
    }

    function setMPV(address _masterPropertyValue)
    public
    mpvAccessOnly(msg.sender)
    {
        masterPropertyValue = MasterPropertyValue(_masterPropertyValue);
    }

    function setMintingAdmin(address _mintingAdmin)
    public
    onlyMintingAdmin
    {
        mintingAdmin = _mintingAdmin;
    }

    function setRedemptionAdmin(address _redemptionAdmin)
    public
    onlyRedemptionAdmin
    {
        redemptionAdmin = _redemptionAdmin;
    }

    function setDailyLimit(uint256 _dailyLimit) public {
        dailyLimit = _dailyLimit;
    }

    function transfer(address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused()
    returns (bool)
    {
        require(_isUnderLimit(msg.sender, value));
        dailyLimits[msg.sender].spentToday += value;
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused()
    returns (bool)
    {
        require(_isUnderLimit(from, value));
        dailyLimits[from].spentToday += value;
        return super.transferFrom(from, to, value);
    }

    function mint(address account, uint value)
    public
    onlyMintingAdmin
    whitelistedAddress(account)
    {
        _mint(account, value);
    }

    function burn(address account, uint value)
    public
    onlyRedemptionAdmin
    {
        _burn(account, value);
    }

    function _isUnderLimit(address account, uint amount)
    internal
    returns (bool)
    {
        DailyLimitInfo storage limitInfo = dailyLimits[account];

        if (now > limitInfo.lastDay + 24 hours) {
            limitInfo.lastDay = now;
            limitInfo.spentToday = 0;
        }

        if (
            limitInfo.spentToday + amount > dailyLimit ||
            limitInfo.spentToday + amount < limitInfo.spentToday
        ) {
            return false;
        }

        return true;
    }
}
