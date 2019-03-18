pragma solidity >=0.4.21 <0.6.0;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import './Whitelist.sol';


contract MPVToken is Initializable, ERC20, ERC20Detailed {

  Whitelist whitelist;

  function initialize(
    string memory name,
    string memory symbol,
    uint8 decimals,
    address _whitelist
  ) public initializer {
    ERC20Detailed.initialize(name, symbol ,decimals);
    whitelist = Whitelist(_whitelist);
  }

  function transfer(address to, uint256 value) public returns (bool) {
    require(whitelist.isWhitelisted(to));
    _transfer(msg.sender, to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value) public returns (bool) {
    require(whitelist.isWhitelisted(to));
    return super.transferFrom(from, to, value);
  }

  function mint(address account, uint value) public {
    _mint(account, value);
  }
}
