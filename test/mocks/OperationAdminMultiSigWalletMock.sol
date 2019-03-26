pragma solidity ^0.5.1;

import '../../contracts/OperationAdminMultiSigWallet.sol';

contract OperationAdminMultiSigWalletMock is OperationAdminMultiSigWallet {

  constructor(address[] memory _owners, uint _required)
      public
      OperationAdminMultiSigWallet(_owners, _required)
  {

  }

  function hasOwner(address account) public view returns (bool){
    return true;
  }
}
