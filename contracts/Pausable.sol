pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Initializable {
    /*
     *  Events
     */
    event Paused(address account);
    event Unpaused(address account);

    /*
     *  Storage
     */
    bool private _paused;
    address public pausableAdmin;

    /*
     *  Modifiers
     */
    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(_paused);
        _;
    }

    /// @dev Modifier to make a function callable only the sender is the MPV contract.
    modifier onlyPausableAdmin() {
        require(msg.sender == pausableAdmin);
        _;
    }

    /*
     * Public functions
     */
    /// @dev Contract constructor sets initial paused state.
    constructor() public {
        _paused = false;
        pausableAdmin = msg.sender;
    }

    function setPausableAdmin(
        address admin
    ) public onlyPausableAdmin {
        pausableAdmin = admin;
    }

    /// @dev Returns true if the contract is paused, false otherwise.
    /// @return Paused state.
    function paused() public view returns (bool) {
        return _paused;
    }

    /// @dev Called by the owner to pause, triggers stopped state.
    function pause() public whenNotPaused onlyPausableAdmin {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @dev Called by the owner to unpause, returns to normal state.
    function unpause() public whenPaused onlyPausableAdmin {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}