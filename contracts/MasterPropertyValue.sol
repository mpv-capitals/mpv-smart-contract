pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./Pausable.sol";
import "./MPVAccessControl.sol";
import "./MPVToken.sol";
import "./Assets.sol";
import "./IWhitelist.sol";


contract MasterPropertyValue is Initializable, Pausable, MPVAccessControl {
    MPVToken public mpvToken;
    Assets public assets;
    IWhitelist public whitelist;

    function initialize(
        MPVToken _mpvToken,
        Assets _assets,
        IWhitelist _whitelist
    ) public initializer {
        mpvToken = _mpvToken;
        assets = _assets;
        whitelist = _whitelist;

        mpvToken.setMPV(address(this));
    }
}
