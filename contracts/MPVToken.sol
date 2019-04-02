pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import "./Whitelist.sol";
import "./MasterPropertyValue.sol";


/**
 * @title MPVToken
 * @dev The MPV Token contract.
 */
contract MPVToken is Initializable, ERC20, ERC20Detailed {
    /*
     *  Storage
     */
    Whitelist public whitelist;
    MasterPropertyValue public masterPropertyValue;
    address public mintingAdmin;
    address public redemptionAdmin;
    mapping(address => DailyLimitInfo) public dailyLimits;
    uint256 public dailyLimit;

    /// @dev Daily limit info structure.
    struct DailyLimitInfo {
        uint lastDay;
        uint spentToday;
    }

    /*
     *  Modifiers
     */
    /// @dev Requires that account address is whitelisted.
    /// @param account Address of account.
    modifier whitelistedAddress(address account) {
        require(whitelist.isWhitelisted(account));
        _;
    }

    /// @dev Requires that account address is the MPV contract.
    /// @param account Address of account.
    modifier mpvAccessOnly(address account) {
        require(account == address(masterPropertyValue));
        _;
    }

    /// @dev Requires the sender to be the minting admin role contract.
    modifier onlyMintingAdmin() {
        require(mintingAdmin == msg.sender);
        _;
    }

    /// @dev Requires the sender to be the redemption admin role contract.
    modifier onlyRedemptionAdmin() {
        require(mintingAdmin == msg.sender);
        _;
    }

    /// @dev Requires that the main MPV contract is not paused.
    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    /*
     *  Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param name Name of token.
    /// @param symbol Symbol of token.
    /// @param decimals Number of decimals for token.
    /// @param _whitelist Whitelist contract address.
    /// @param _masterPropertyValue Main MPV contract address.
    /// @param _mintingAdmin Minting admin role contract address.
    /// @param _redemptionAdmin Redemption admin role contract address.
    /// @param _dailyLimit Daily limit amount.
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        Whitelist _whitelist,
        MasterPropertyValue _masterPropertyValue,
        address _mintingAdmin,
        address _redemptionAdmin,
        uint256 _dailyLimit
    )
    public
    initializer
    {
        ERC20Detailed.initialize(name, symbol, decimals);
        whitelist = _whitelist;
        masterPropertyValue = _masterPropertyValue;
        mintingAdmin = _mintingAdmin;
        redemptionAdmin = _redemptionAdmin;
        dailyLimit = _dailyLimit;
    }

    /// @dev Set the MPV contract address.
    /// @param _masterPropertyValue Address of main MPV contract.
    function setMPV(address _masterPropertyValue)
    public
    mpvAccessOnly(msg.sender)
    mpvNotPaused
    {
        masterPropertyValue = MasterPropertyValue(_masterPropertyValue);
    }

    /// @dev Set the minting admin role contract address.
    /// @param _mintingAdmin Address of minting admin role contract.
    function setMintingAdmin(address _mintingAdmin)
    public
    onlyMintingAdmin
    mpvNotPaused
    {
        mintingAdmin = _mintingAdmin;
    }

    /// @dev Set the redemption admin role contract address.
    /// @param _redemptionAdmin Address of redemption admin role contract.
    function setRedemptionAdmin(address _redemptionAdmin)
    public
    onlyRedemptionAdmin
    mpvNotPaused
    {
        redemptionAdmin = _redemptionAdmin;
    }

    function setDailyLimit(uint256 _dailyLimit) public {
        dailyLimit = _dailyLimit;
    }

    /// @dev Transfer tokens to another account.
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return Success boolean.
    function transfer(address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused
    returns (bool)
    {
        require(_isUnderLimit(msg.sender, value));
        dailyLimits[msg.sender].spentToday += value;
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @dev Transfer tokens from an account to another account.
    /// @param from Address to transfer tokens from.
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return Success boolean.
    function transferFrom(address from, address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused
    returns (bool)
    {
        require(_isUnderLimit(from, value));
        dailyLimits[from].spentToday += value;
        return super.transferFrom(from, to, value);
    }

    /// @dev Mint new tokens.
    /// @param account Address to send newly minted tokens to.
    /// @param value Amount of tokens to mint.
    function mint(address account, uint value)
    public
    onlyMintingAdmin
    whitelistedAddress(account)
    mpvNotPaused
    {
        _mint(account, value);
    }

    /// @dev Burn tokens.
    /// @param account Address to burn tokens from.
    /// @param value Amount of tokens to burn.
    function burn(address account, uint value)
    public
    onlyRedemptionAdmin
    mpvNotPaused
    {
        _burn(account, value);
    }

    /*
     *  Internal functions
     */
    /// @dev Returns true if token holder is under daily limit of transfers.
    /// @param account Address of account.
    /// @param amount Amount of tokens account needing to transfer.
    /// @return boolean.
    function _isUnderLimit(address account, uint amount)
    internal
    returns (bool)
    {
        DailyLimitInfo storage limitInfo = dailyLimits[account];

        if (now > limitInfo.lastDay + 24 hours) {
            limitInfo.lastDay = now;
            limitInfo.spentToday = 0;
        }

        if (
            limitInfo.spentToday + amount > dailyLimit ||
            limitInfo.spentToday + amount < limitInfo.spentToday
        ) {
            return false;
        }

        return true;
    }
}
