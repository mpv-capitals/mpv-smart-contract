pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import '../../contracts/Assets.sol';

contract AssetsMock is Assets {
  uint256 private _totalTokens;

  function totalTokens() public returns(uint256) {
      return _totalTokens;
  }

  function mock_updateTotalTokens(uint256 value) public {
      _totalTokens = value;
  }

  function mock_addTotalTokens(uint256 value) public {
      _totalTokens = _totalTokens.add(value);
  }

  function mock_subTotalTokens(uint256 value) public {
      _totalTokens = _totalTokens.sub(value);
  }
}
