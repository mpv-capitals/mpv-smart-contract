pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./IMultiSigWallet.sol";
import "./IWhitelist.sol";
import "./Assets.sol";
import "./Pausable.sol";
import "./SuperOwnerRole.sol";
import "./BasicOwnerRole.sol";
import "./OperationAdminRole.sol";
import "./MintingAdminRole.sol";
import "./RedemptionAdminRole.sol";
import "./MPVToken.sol";
import "./MPVAccessControl.sol";
import "./AdministeredMultiSigWallet.sol";


contract MasterPropertyValue is Initializable, Pausable, MPVAccessControl {
    using SafeMath for uint256;

    MPVToken public mpvToken;
    Assets public assets;
    IWhitelist public whitelist;

    SuperOwnerRole public superOwnerRole;
    BasicOwnerRole public basicOwnerRole;
    MintingAdminRole public mintingAdminRole;
    OperationAdminRole public operationAdminRole;
    RedemptionAdminRole public redemptionAdminRole;

    IMultiSigWallet public superOwnerMultiSig;
    IMultiSigWallet public operationAdminMultiSig;
    IMultiSigWallet public mintingAdminMultiSig;
    IMultiSigWallet public redemptionAdminMultiSig;

    function initialize(
        MPVToken _mpvToken,
        Assets _assets,
        IWhitelist _whitelist,
        AdministeredMultiSigWallet _superOwnerMultiSig,
        SuperOwnerRole _superOwnerRole,
        AdministeredMultiSigWallet _basicOwnerMultiSig,
        AdministeredMultiSigWallet _operationAdminMultiSig,
        AdministeredMultiSigWallet _mintingAdminMultiSig,
        MintingAdminRole _mintingAdminRole,
        AdministeredMultiSigWallet _redemptionAdminMultiSig
    ) public initializer {
        // TODO

        mpvToken = _mpvToken;
        mpvToken.setMPV(address(this));
    }
}
