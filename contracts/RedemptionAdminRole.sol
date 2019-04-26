pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./MasterPropertyValue.sol";
import "./IMultiSigWallet.sol";
import "./MPVToken.sol";
import "./Assets.sol";

/**
 * @title RedemptionAdminRole
 * @dev Redemption admin role contract.
 */
contract RedemptionAdminRole is Initializable {
    using SafeMath for uint256;

    /*
     *  Events
     */
    event BurningCountdownStarted(
            address indexed sender,
            uint256 indexed assetId,
            uint256 indexed tokens
    );

    event RedemptionRejected(address indexed sender, uint256 indexed assetId);

    event BurningActionCountdownUpdated(address indexed sender, uint256 indexed countdown);

    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    IMultiSigWallet public basicOwnerMultiSig;
    address public superOwnerMultiSig;
    Assets public assets;
    MPVToken public mpvToken;
    uint256 public burningActionCountdownLength;
    mapping(uint256 => uint256) public redemptionCountdowns;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    /// @dev Requires the sender to be the redemption admin multisig contract.
    modifier onlyRedemptionAdminMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    /// @dev Requires the sender an owner of the redemptionAdminMultiSig
    modifier onlyRedemptionAdminOwner() {
        require(multiSig.hasOwner(msg.sender));
        _;
    }

    /// @dev Requires the sender to be an owner of the SuperOwnerMultiSig
    modifier onlySuperOwnerMultiSig() {
        require(superOwnerMultiSig == (msg.sender));
        _;
    }

    /// @dev Requires that the MPV contract is not paused.
    modifier mpvNotPaused() {
        require(masterPropertyValue.paused() == false);
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param _multiSig Address of the redemption admin multisig contract.
    /// @param _assets Address of the assets contract.
    function initialize(
        IMultiSigWallet _multiSig,
        IMultiSigWallet _basicOwnerMultiSig,
        address _superOwnerMultiSig,
        Assets _assets,
        MPVToken _mpvToken,
        MasterPropertyValue _masterPropertyValue
    ) public initializer {
        multiSig = _multiSig;
        basicOwnerMultiSig = _basicOwnerMultiSig;
        superOwnerMultiSig = _superOwnerMultiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        masterPropertyValue = _masterPropertyValue;
        burningActionCountdownLength = 48 hours;
    }

    /// @dev Start the countdown to initiate burning of tokens. Transaction has
    /// to be sent by the redemption admin multisig.
    /// @param assetId Id of asset being redeemed.
    function startBurningCountdown(uint256 assetId)
        public
        onlyRedemptionAdminMultiSig
        mpvNotPaused
    {
        (
            ,/*id*/
            Assets.Status status,
            ,/*notarizationId*/
            uint256 tokens,
            ,/*owner*/
            /*timestamp*/
        ) =  assets.get(assetId);

        require(status == Assets.Status.Locked);
        redemptionCountdowns[assetId] = now;
        emit BurningCountdownStarted(msg.sender, assetId, tokens);
    }

    /// @dev Reject a redemption request. Transaction has to be sent by
    /// a redemption admin.
    /// @param assetId Id of asset being redeemed.
    function rejectRedemption(uint256 assetId)
        public
        onlyRedemptionAdminOwner
        mpvNotPaused
    {
        assets.rejectRedemption(assetId);
        emit RedemptionRejected(msg.sender, assetId);
    }

    function executeRedemption(uint256 assetId)
        public
    {
        require(
            multiSig.hasOwner(msg.sender) ||
            basicOwnerMultiSig.hasOwner(msg.sender)
        );
        require(
            now > redemptionCountdowns[assetId].add(burningActionCountdownLength)
        );

        (uint256 amount, ,) = assets.redemptionTokenLocks(assetId);
        mpvToken.burn(address(assets), amount);
        assets.executeRedemption(assetId);
    }

    /// @dev Set the countdown length for the action of burning of tokens.
    /// Transaction has to be sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function updateBurningActionCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    mpvNotPaused
    {
        burningActionCountdownLength = newCountdown;
        emit BurningActionCountdownUpdated(msg.sender, newCountdown);
    }
}
