pragma solidity ^0.5.1;

import '../../contracts/AdministeredMultiSigWallet.sol';

contract BasicOwnerMultiSigWalletMock is AdministeredMultiSigWallet {

  constructor(address[] memory _owners, uint _required)
      public
      AdministeredMultiSigWallet(_owners, _required)
  {

  }

  function hasOwner(address account) public view returns (bool){
    return true;
  }
}
