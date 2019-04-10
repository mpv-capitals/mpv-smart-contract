pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./Pausable.sol";
import "./MPVToken.sol";
import "./Assets.sol";
import "./Whitelist.sol";


/**
 * @title MasterPropertyValue
 * @dev The main Master Property Value contract.
 */
contract MasterPropertyValue is Initializable, Pausable {
    /*
     *  Storage
     */
    MPVToken public mpvToken;
    Assets public assets;
    Whitelist public whitelist;

    /*
     * Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param _mpvToken Address of the MPV Token contract.
    /// @param _assets Address of the Assets contract.
    /// @param _whitelist Address of the whitelist contract.
    function initialize(
        MPVToken _mpvToken,
        Assets _assets,
        Whitelist _whitelist
    ) public initializer {
        super.initialize();
        mpvToken = _mpvToken;
        assets = _assets;
        whitelist = _whitelist;

        mpvToken.updateMPV(address(this));
    }
}
