pragma solidity ^0.5.1;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";
import "./ERC20.sol";
import "openzeppelin-eth/contracts/token/ERC20/ERC20Detailed.sol";
import "./Assets.sol";
import "./Whitelist.sol";
import "./MasterPropertyValue.sol";


/**
 * @title MPVToken
 * @dev The MPV Token contract.
 */
contract MPVToken is Initializable, ERC20, ERC20Detailed {
    using SafeMath for uint256;

    /*
     *  Events
     */
    event DailyLimitUpdatePending(address account, uint256 currentDailyLimit, uint256 updatedDailyLimit);
    event DailyLimitUpdateCancelled(address account, uint256 dailyLimit);
    event DailyLimitUpdated(address indexed sender, uint256 indexed dailyLimit);
    event DailyLimitUpdateFulfilled(address account, uint256 newDailyLimit);
    event DelayedTransferCountdownLengthUpdated(address superProtectorMultisig, uint256 updatedCountdownLength);

    event DelayedTransferInitiated(
        address from,
        address to,
        uint256 value,
        address sender,
        uint256 countdownStart,
        TransferMethod transferMethod
    );

    event AssetsUpdated(address indexed sender, address indexed addr);
    event MintingAdminUpdated(address indexed sender, address indexed admin);
    event MPVUpdated(address indexed sender, address indexed addr);
    event RedemptionAdminUpdated(address indexed sender, address indexed admin);
    event SuperProtectorMultiSigUpdated(address indexed sender, address indexed addr);
    event UpdateDailyLimitCountdownLengthUpdated(address superProtectorMultisig, uint256 updatedCountdownLength);


    /*
     *  Storage
     */
    Assets public assets;
    Whitelist public whitelist;
    MasterPropertyValue public masterPropertyValue;
    address public mintingAdmin;
    address public redemptionAdmin;
    address public superProtectorMultiSig;
    uint256 public updateDailyLimitCountdownLength;
    uint256 public delayedTransferCountdownLength;
    uint256 public delayedTransferNonce;
    mapping(address => DailyLimitInfo) public dailyLimits;
    mapping(uint256 => DelayedTransfer) public delayedTransfers;

    /// @dev Daily limit info structure.
    struct DailyLimitInfo {
        uint256 lastDay;
        uint256 spentToday;
        uint256 dailyLimit;
        uint256 countdownStart;
        uint256 updatedDailyLimit;
    }

    struct DelayedTransfer {
        address from;
        address to;
        address sender;
        uint256 value;
        uint256 countdownStart;
        TransferMethod transferMethod;
    }

    enum TransferMethod {
        Transfer,
        TransferFrom
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

    /// @dev Requires the sender to be the super protector multiSig contract.
    modifier onlySuperProtectorMultiSig() {
        require(superProtectorMultiSig == msg.sender);
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

    /// @dev Requires the sender to be the basic protector multiSig contract.
    modifier onlyBasicProtectorMultiSig() {
        require(basicProtectorMultiSig == msg.sender);
        _;
    }

    // NOTE: NEW STORAGE IS APPENDED HERE

    event SweepAddressUpdated(address indexed sender, address originalAddress, address indexed sweepAddress, address indexed exchangeOwnedAddress);
    event OriginalTransfer(address originalFrom, address originalTo, uint256 amount);
    mapping (address => address) public sweepAddresses;
    address public basicProtectorMultiSig;
    event BasicProtectorMultiSigUpdated(address indexed sender, address indexed addr);

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
        address _redemptionAdmin,
        address _superProtectorMultiSig
    )
    public
    initializer
    {
        ERC20Detailed.initialize(name, symbol, decimals);
        whitelist = _whitelist;
        masterPropertyValue = _masterPropertyValue;
        mintingAdmin = _mintingAdmin;
        redemptionAdmin = _redemptionAdmin;
        superProtectorMultiSig = _superProtectorMultiSig;
        updateDailyLimitCountdownLength = 48 hours;
        delayedTransferCountdownLength = 48 hours;
        delayedTransferNonce = 0;
    }

    /// @dev Set the MPV contract address.
    /// @param _masterPropertyValue Address of main MPV contract.
    function updateMPV(address _masterPropertyValue)
    public
    mpvAccessOnly(msg.sender)
    mpvNotPaused
    {
        require(_masterPropertyValue != address(0));
        masterPropertyValue = MasterPropertyValue(_masterPropertyValue);
        emit MPVUpdated(msg.sender, _masterPropertyValue);
    }

    /// @dev Set the minting admin role contract address.
    /// @param _mintingAdmin Address of minting admin role contract.
    function updateMintingAdmin(address _mintingAdmin)
    public
    onlyMintingAdmin
    mpvNotPaused
    {
        require(_mintingAdmin != address(0));
        mintingAdmin = _mintingAdmin;
        emit MintingAdminUpdated(msg.sender, _mintingAdmin);
    }

    function updateSuperProtectorMultiSig(address _multisig)
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        require(_multisig != address(0));
        superProtectorMultiSig = _multisig;
        emit SuperProtectorMultiSigUpdated(msg.sender, _multisig);
    }

    // this function is called once immediately after upgrade
    function initializeBasicProtectorMultiSig(address _multisig)
    public {
        require(basicProtectorMultiSig == address(0));
        require(_multisig != address(0));
        basicProtectorMultiSig = _multisig;
        emit BasicProtectorMultiSigUpdated(msg.sender, _multisig);
    }

    function updateBasicProtectorMultiSig(address _multisig)
    public
    onlyBasicProtectorMultiSig
    mpvNotPaused
    {
        require(_multisig != address(0));
        basicProtectorMultiSig = _multisig;
        emit BasicProtectorMultiSigUpdated(msg.sender, _multisig);
    }

    /// @dev Set the assets contract address.
    /// @param _assets Address of assets contract.
    function updateAssets(address _assets)
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        require(_assets != address(0));
        assets = Assets(_assets);
        emit AssetsUpdated(msg.sender, _assets);
    }

    /// @dev Set the redemption admin role contract address.
    /// @param _redemptionAdmin Address of redemption admin role contract.
    function updateRedemptionAdmin(address _redemptionAdmin)
    public
    onlyRedemptionAdmin
    mpvNotPaused
    {
        redemptionAdmin = _redemptionAdmin;
        emit RedemptionAdminUpdated(msg.sender, _redemptionAdmin);
    }

    /// @dev Update the updateDailyLimitCountdownLength
    /// @param updatedCountdownLength Address of redemption admin role contract.
    function updateUpdateDailyLimitCountdownLength(uint256 updatedCountdownLength)
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        updateDailyLimitCountdownLength = updatedCountdownLength;
        emit UpdateDailyLimitCountdownLengthUpdated(msg.sender, updatedCountdownLength);
    }

    /// @dev Update the delayedTransferCountdownLength
    /// @param updatedCountdownLength Address of redemption admin role contract.
    function updateDelayedTransferCountdownLength(uint256 updatedCountdownLength)
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        delayedTransferCountdownLength = updatedCountdownLength;
        emit DelayedTransferCountdownLengthUpdated(msg.sender, updatedCountdownLength);
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

        require(limitInfo.countdownStart.add(updateDailyLimitCountdownLength) < now);
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
    enforceDailyLimit(msg.sender, value)
    mpvNotPaused
    returns (bool)
    {
        dailyLimits[msg.sender].spentToday = dailyLimits[msg.sender].spentToday.add(value);
        return _transferToken(msg.sender, to, value, false);
    }

    /// @dev Transfer tokens from an account to another account.
    /// @param from Address to transfer tokens from.
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return Success boolean.
    function transferFrom(address from, address to, uint256 value)
    public
    mpvNotPaused
    enforceDailyLimit(from, value)
    returns (bool)
    {
        dailyLimits[from].spentToday = dailyLimits[from].spentToday.add(value);
        return _transferToken(from, to, value, true);
    }

    /// @dev Starts delayedTransferCountdown to execute transfer in 48 hours
    ///      and allows value to exceed daily transfer limit
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return transferId The corresponding transferId for delayedTransfers mapping
    function delayedTransfer(address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused
    returns (uint256 transferId)
    {
        transferId = delayedTransferNonce++;
        DelayedTransfer storage delayedTransfer = delayedTransfers[transferId];
        delayedTransfer.from = msg.sender;
        delayedTransfer.to = to;
        delayedTransfer.value = value;
        delayedTransfer.countdownStart = now;
        delayedTransfer.transferMethod = TransferMethod.Transfer;
        emit DelayedTransferInitiated(
            msg.sender,
            to,
            value,
            address(0),
            delayedTransfer.countdownStart,
            TransferMethod.Transfer
        );
    }

    /// @dev Starts delayedTransferCountdown to execute transfer in 48 hours
    ///      and allows value to exceed daily transfer limit
    /// @param from Address to transfer tokens from.
    /// @param to Address to transfer tokens to.
    /// @param value Amount of tokens to transfer.
    /// @return transferId The corresponding transferId for delayedTransfers mapping
    function delayedTransferFrom(address from, address to, uint256 value)
    public
    whitelistedAddress(to)
    mpvNotPaused
    returns (uint256 transferId)
    {
        transferId = delayedTransferNonce++;
        DelayedTransfer storage delayedTransfer = delayedTransfers[transferId];
        delayedTransfer.from = from;
        delayedTransfer.to = to;
        delayedTransfer.sender = msg.sender;
        delayedTransfer.value = value;
        delayedTransfer.countdownStart = now;
        delayedTransfer.transferMethod = TransferMethod.TransferFrom;
        emit DelayedTransferInitiated(
            from,
            to,
            value,
            msg.sender,
            delayedTransfer.countdownStart,
            TransferMethod.Transfer
        );
    }

    /// @dev Executes delayedTransfer given countdown has expired and recipient
    ///      is a whitelisted address
    /// @param transferId The corresponding transferId
    /// @return success boolean
    function executeDelayedTransfer(uint256 transferId)
    public
    mpvNotPaused
    returns (bool success)
    {
        DelayedTransfer storage delayedTransfer = delayedTransfers[transferId];
        require(whitelist.isWhitelisted(delayedTransfer.to));
        require(delayedTransfer.countdownStart.add(delayedTransferCountdownLength) < now);

        if (delayedTransfer.transferMethod == TransferMethod.Transfer) {
            success = _transferToken(msg.sender, delayedTransfer.to, delayedTransfer.value, false);
        } else if (delayedTransfer.transferMethod == TransferMethod.TransferFrom) {
            success = _transferToken(delayedTransfer.from, delayedTransfer.to, delayedTransfer.value, true);
        }

        delete delayedTransfers[transferId];
    }

    /// @dev Cancels a delayedTransfer if called by the initiator of the transfer
    ///      or the owner of the funds
    /// @param transferId The corresponding transferId
    /// @return success boolean
    function cancelDelayedTransfer(uint256 transferId)
    public
    mpvNotPaused
    returns (bool success)
    {
        DelayedTransfer storage delayedTransfer = delayedTransfers[transferId];
        require(msg.sender == delayedTransfer.from || msg.sender == delayedTransfer.sender);
        delete delayedTransfers[transferId];
        return true;
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
        uint256 newTotal = totalSupply().add(value);
        uint256 totalTokens = assets.totalTokens();
        require(newTotal == totalTokens);

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
        uint256 newTotal = totalSupply().sub(value);
        uint256 totalTokens = assets.totalTokens();
        require(newTotal == totalTokens);

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
    ) public view returns (uint8 returnValue) {
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
            return "Valid transfer";
        if (restrictionCode == 1)
            return "Invalid transfer: nonwhitelisted recipient";
        if (restrictionCode == 2) {
            return "Invalid transfer: exceeds daily limit";
        } else {
            revert("Invalid restrictionCode");
        }
    }

    function updateSweepAddress(
        address addr,
        address exchangeOwnedAddress
    ) public onlyBasicProtectorMultiSig {
        address sweepAddress = computeSweepAddress(addr);
        require(sweepAddress != address(0));

        sweepAddresses[sweepAddress] = exchangeOwnedAddress;
        emit SweepAddressUpdated(msg.sender, addr, sweepAddress, exchangeOwnedAddress);
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
    returns (bool isUnderLimit) {
        DailyLimitInfo storage limitInfo = dailyLimits[account];

        if (now > limitInfo.lastDay + 24 hours) {
            limitInfo.lastDay = now;
            limitInfo.spentToday = 0;
        }

        if (
            limitInfo.countdownStart != 0 &&
            now > limitInfo.countdownStart.add(updateDailyLimitCountdownLength)
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
    returns(bool) {
        return (
            // NOTE: 0 == no daily limit
            limitInfo.dailyLimit == 0 ||
            limitInfo.spentToday.add(amount) <= limitInfo.dailyLimit
        );
    }

    function _transferToken(
        address sender,
        address recipient,
        uint256 amount,
        bool isTransferFrom
    )
    internal
    returns (bool result) {
        require(sender != address(0));
        require(recipient != address(0));

        address newRecipient = computeSweepAddress(recipient);
        address exchangeAddress = sweepAddresses[newRecipient];

        if (exchangeAddress != address(0)) {
            require(whitelist.isWhitelisted(exchangeAddress));

            emit Transfer(sender, recipient, amount);
            emit Transfer(recipient, exchangeAddress, amount);

            if (isTransferFrom) {
                result = super.transferFrom(sender, exchangeAddress, amount);
            } else {
                result = super.transfer(exchangeAddress, amount);
            }

            emit OriginalTransfer(sender, recipient, amount);
        } else {
            require(whitelist.isWhitelisted(recipient));

            if (isTransferFrom) {
                result = super.transferFrom(sender, recipient, amount);
            } else {
                result = super.transfer(recipient, amount);
            }

            emit Transfer(sender, recipient, amount);
        }
    }

    function computeSweepAddress(address addr)
        public
        pure
        returns (address) {
        return address(uint(addr) >> 20);
    }
}
