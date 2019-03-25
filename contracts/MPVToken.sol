pragma solidity >=0.4.21 <0.6.0;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import './Whitelist.sol';
import './MasterPropertyValue.sol';


contract MPVToken is Initializable, ERC20, ERC20Detailed {

  Whitelist public whitelist;
  MasterPropertyValue public masterPropertyValue;
  mapping(address => DailyLimitInfo) public dailyLimits;

  struct DailyLimitInfo {
    uint lastDay;
    uint spentToday;
  }

  modifier whitelistedAddress(address addr) {
    require(whitelist.isWhitelisted(addr));
    _;
  }

  modifier MPVAccessOnly(address addr) {
    require(addr == address(masterPropertyValue));
    _;
  }

  modifier MPVNotPaused() {
    require(masterPropertyValue.paused() == false);
    _;
  }

  function initialize(
    string memory name,
    string memory symbol,
    uint8 decimals,
    Whitelist _whitelist,
    MasterPropertyValue _masterPropertyValue

  ) public initializer
  {
    ERC20Detailed.initialize(name, symbol ,decimals);
    whitelist = _whitelist;
    masterPropertyValue = _masterPropertyValue;
  }

  function setMPV(address _masterPropertyValue)
  MPVAccessOnly(msg.sender)
  public {
    masterPropertyValue = MasterPropertyValue(_masterPropertyValue);
  }

  function transfer(address to, uint256 value)
    public
    whitelistedAddress(to)
    MPVNotPaused()
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
    MPVNotPaused()
    returns (bool)
  {
    require(_isUnderLimit(from, value));
    dailyLimits[from].spentToday += value;
    return super.transferFrom(from, to, value);
  }

  function mint(address account, uint value)
    public
    MPVAccessOnly(msg.sender)
    whitelistedAddress(account)
  {
    _mint(account, value);
  }

  function burn(address account, uint value)
    public
    MPVAccessOnly(msg.sender)
  {
    _burn(account, value);
  }

  function _isUnderLimit(address account, uint amount)
    internal
    returns (bool)
  {
    uint dailyLimit = masterPropertyValue.dailyTransferLimit();
    DailyLimitInfo storage limitInfo = dailyLimits[account];
    if (now > limitInfo.lastDay + 24 hours) {
      limitInfo.lastDay = now;
      limitInfo.spentToday = 0;
    }
    if (
      limitInfo.spentToday + amount > dailyLimit ||
      limitInfo.spentToday + amount < limitInfo.spentToday
    )
      return false;
    return true;
  }
}
