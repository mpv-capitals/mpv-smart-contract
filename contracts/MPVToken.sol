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

    event DailyLimitUpdatePending(address account, uint256 currentDailyLimit, uint256 updatedDailyLimit);
    event DailyLimitUpdateCancelled(address account, uint256 dailyLimit);
    event DailyLimitUpdateFulfilled(address account, uint256 newDailyLimit);
    /*
     *  Events
     */
    event MPVUpdated(address indexed sender, address indexed addr);
    event MintingAdminUpdated(address indexed sender, address indexed admin);
    event RedemptionAdminUpdated(address indexed sender, address indexed admin);
    event DailyLimitUpdated(address indexed sender, uint256 indexed dailyLimit);

    /*
     *  Storage
     */
    Whitelist public whitelist;
    MasterPropertyValue public masterPropertyValue;
    address public mintingAdmin;
    address public redemptionAdmin;
    uint256 public countdownLength;
    mapping(address => DailyLimitInfo) public dailyLimits;

    /// @dev Daily limit info structure.
    struct DailyLimitInfo {
        uint256 lastDay;
        uint256 spentToday;
        uint256 dailyLimit;
        uint256 countdownStart;
        uint256 updatedDailyLimit;
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
        require(redemptionAdmin == msg.sender);
        _;
    }

    /// @dev Requires that the main MPV contract is not paused.
    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    /// @dev Requires that transfer does not exceed account daily limit
    modifier enforceDailyLimit(address account, uint256 value) {
        require(_enforceLimit(account, value));
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
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        Whitelist _whitelist,
        MasterPropertyValue _masterPropertyValue,
        address _mintingAdmin,
        address _redemptionAdmin
    )
    public
    initializer
    {
        ERC20Detailed.initialize(name, symbol, decimals);
        whitelist = _whitelist;
        masterPropertyValue = _masterPropertyValue;
        mintingAdmin = _mintingAdmin;
        redemptionAdmin = _redemptionAdmin;
        countdownLength = 48 hours;
    }

    /// @dev Set the MPV contract address.
    /// @param _masterPropertyValue Address of main MPV contract.
    function setMPV(address _masterPropertyValue)
    public
    mpvAccessOnly(msg.sender)
    mpvNotPaused
    {
        masterPropertyValue = MasterPropertyValue(_masterPropertyValue);
        emit MPVUpdated(msg.sender, _masterPropertyValue);
    }

    /// @dev Set the minting admin role contract address.
    /// @param _mintingAdmin Address of minting admin role contract.
    function setMintingAdmin(address _mintingAdmin)
    public
    onlyMintingAdmin
    mpvNotPaused
    {
        mintingAdmin = _mintingAdmin;
        emit MintingAdminUpdated(msg.sender, _mintingAdmin);
    }

    /// @dev Set the redemption admin role contract address.
    /// @param _redemptionAdmin Address of redemption admin role contract.
    function setRedemptionAdmin(address _redemptionAdmin)
    public
    onlyRedemptionAdmin
    mpvNotPaused
    {
        redemptionAdmin = _redemptionAdmin;
        emit RedemptionAdminUpdated(msg.sender, _redemptionAdmin);
    }

    /// @dev Sets new daily limit for sender account after countdown resolves
    /// @param updatedDailyLimit Updated dailyLimit
    function updateDailyLimit(uint256 updatedDailyLimit)
    public
    {
        DailyLimitInfo storage limitInfo = dailyLimits[msg.sender];

        limitInfo.updatedDailyLimit = updatedDailyLimit;
        limitInfo.countdownStart = now;
        emit DailyLimitUpdatePending(msg.sender, limitInfo.dailyLimit, updatedDailyLimit);
    }

    /// @dev Cancels dailyLimit update for sender if countdown hasn't
    ///      yet expired
    function cancelDailyLimitUpdate() public {
      DailyLimitInfo storage limitInfo = dailyLimits[msg.sender];

      require(limitInfo.countdownStart + countdownLength < now);
      limitInfo.countdownStart = 0;
      limitInfo.updatedDailyLimit = 0;
      emit DailyLimitUpdateCancelled(msg.sender, limitInfo.dailyLimit);
    }

    /// @dev Transfer tokens to another account.
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return Success boolean.
    function transfer(address to, uint256 value)
    public
    whitelistedAddress(to)
    enforceDailyLimit(msg.sender, value)
    mpvNotPaused
    returns (bool)
    {
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
    enforceDailyLimit(from, value)
    returns (bool)
    {
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
     *  ERC1404 Implementation
     */
     /// @dev View function that allows a quick check on daily limits
     /// @param from Address to transfer tokens from.
     /// @param to Address to transfer tokens to.
     /// @param value Amount of tokens to transfer.
     /// @return Returns uint8 0 on valid transfer any other number on invalid transfer
     function detectTransferRestriction(
         address from,
         address to,
         uint256 value
      ) public view returns (uint8 returnValue)
      {
          DailyLimitInfo storage limitInfo = dailyLimits[from];

          if (!whitelist.isWhitelisted(to)) {
            return 1;
          }

          // if daily limit exists
          if (limitInfo.dailyLimit != 0){
            // if new day, only check current transfer value
            if (now > limitInfo.lastDay + 24 hours) {
                if (value > limitInfo.dailyLimit) {
                  return 2;
                }
            // if daily period not over, check against previous transfers
            } else if (!_isUnderLimit(limitInfo, value)) {
              return 2;
            }
          }

          return 0;
      }

      /// @dev Translates uint8 restriction code to a human readable string
      //  @param restrictionCode valid code for transfer restrictions
      /// @return human readable transfer restriction error
      function messageForTransferRestriction (
          uint8 restrictionCode
      ) public view returns (string memory) {
          if (restrictionCode == 0)
              return 'Valid transfer';
          if (restrictionCode == 1)
              return 'Invalid transfer: nonwhitelisted recipient';
          if (restrictionCode == 2) {
              return 'Invalid transfer: exceeds daily limit';
          } else {
              revert('Invalid restrictionCode');
          }
      }

    /*
     *  Internal functions
     */
    /// @dev Updates account info and reverts if daily limit is breached
    /// @param account Address of account.
    /// @param amount Amount of tokens account needing to transfer.
    /// @return boolean.
    function _enforceLimit(address account, uint amount)
    internal
    returns (bool isUnderLimit)
    {
        DailyLimitInfo storage limitInfo = dailyLimits[account];

        if (now > limitInfo.lastDay + 24 hours) {
            limitInfo.lastDay = now;
            limitInfo.spentToday = 0;
        }

        if (
            limitInfo.countdownStart != 0 &&
            now > limitInfo.countdownStart + countdownLength
        ) {
            limitInfo.countdownStart = 0;
            limitInfo.dailyLimit = limitInfo.updatedDailyLimit;
            limitInfo.updatedDailyLimit = 0;
            emit DailyLimitUpdateFulfilled(account, limitInfo.dailyLimit);
        }
        isUnderLimit = _isUnderLimit(limitInfo, amount);
    }

    function _isUnderLimit(DailyLimitInfo memory limitInfo, uint256 amount)
    internal
    pure
    returns(bool)
    {
        return (
          // 0 == no daily limit
          limitInfo.dailyLimit == 0 ||
          limitInfo.spentToday + amount <= limitInfo.dailyLimit
        );
    }
}
