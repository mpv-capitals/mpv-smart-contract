pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./Pausable.sol";
import "./MPVAccessControl.sol";
import "./MPVToken.sol";
import "./Assets.sol";
import "./IWhitelist.sol";
import "./SuperOwnerRole.sol";
import "./BasicOwnerRole.sol";
import "./OperationAdminRole.sol";
import "./MintingAdminRole.sol";
import "./RedemptionAdminRole.sol";


contract MasterPropertyValue is Initializable, Pausable, MPVAccessControl {
    MPVToken public mpvToken;
    Assets public assets;
    IWhitelist public whitelist;

    SuperOwnerRole public superOwnerRole;
    BasicOwnerRole public basicOwnerRole;
    OperationAdminRole public operationAdminRole;
    MintingAdminRole public mintingAdminRole;
    RedemptionAdminRole public redemptionAdminRole;

    function initialize(
        MPVToken _mpvToken,
        Assets _assets,
        IWhitelist _whitelist,

        SuperOwnerRole _superOwnerRole,
        BasicOwnerRole _basicOwnerRole,
        OperationAdminRole _operationAdminRole,
        MintingAdminRole _mintingAdminRole,
        RedemptionAdminRole _redemptionAdminRole
    ) public initializer {
        mpvToken = _mpvToken;
        assets = _assets;
        IWhitelist _whitelist;

        superOwnerRole = _superOwnerRole;
        basicOwnerRole = _basicOwnerRole;
        operationAdminRole = _operationAdminRole;
        mintingAdminRole = _mintingAdminRole;
        redemptionAdminRole = _redemptionAdminRole;

        mpvToken.setMPV(address(this));
    }
}
