pragma solidity >=0.4.21 <0.6.0;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import './Whitelist.sol';


contract MPVToken is Initializable, ERC20, ERC20Detailed {

  Whitelist whitelist;
  address mintingAdmin;
  address redemptionAdmin;

  modifier whitelistedAddress(address addr) {
    require(whitelist.isWhitelisted(addr));
    _;
  }

  modifier mintingAdminOnly(address addr) {
    require(addr == mintingAdmin);
    _;
  }

  modifier redemptionAdminOnly(address addr) {
    require(addr == redemptionAdmin);
    _;
  }

  function initialize(
    string memory name,
    string memory symbol,
    uint8 decimals,
    Whitelist _whitelist,
    address _mintingAdmin,
    address _redemptionAdmin

  ) public initializer {
    ERC20Detailed.initialize(name, symbol ,decimals);
    whitelist = _whitelist;
    mintingAdmin = _mintingAdmin;
    redemptionAdmin = _redemptionAdmin;
  }

  function transfer(address to, uint256 value) public whitelistedAddress(to) returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public whitelistedAddress(to) returns (bool) {
    return super.transferFrom(from, to, value);
  }

  function mint(address account, uint value) public mintingAdminOnly(msg.sender) {
    _mint(account, value);
  }

  function burn(address account, uint value) public redemptionAdminOnly(msg.sender) {
    _burn(account, value);
  }
}
