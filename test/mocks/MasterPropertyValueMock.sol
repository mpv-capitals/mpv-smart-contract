import "../../contracts/MPVToken.sol";

contract MasterPropertyValueMock {
  bool _paused;
  uint public dailyTransferLimit = 1000 * 10 ** 4;

  function paused() public returns (bool) {
    return _paused;
  }

  function mock_setPaused(bool val) public {
    _paused = val;
  }

  function mock_callMint(MPVToken token, address account, uint value) public {
    token.mint(account, value);
  }

  function mock_callBurn(MPVToken token, address account, uint value) public {
    token.burn(account, value);
  }
}
