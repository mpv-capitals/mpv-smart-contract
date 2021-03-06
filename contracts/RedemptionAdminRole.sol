pragma solidity ^0.5.1;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
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
            bytes32 indexed assetId,
            uint256 indexed tokens
    );

    event RedemptionRejected(address indexed sender, bytes32 indexed assetId);

    event BurningActionCountdownUpdated(address indexed sender, uint256 indexed countdown);

    /*
     *  Storage
     */
    IMultiSigWallet public redemptionAdminMultiSig;
    IMultiSigWallet public basicProtectorMultiSig;
    address public superProtectorMultiSig;
    Assets public assets;
    MPVToken public mpvToken;
    uint256 public burningActionCountdownLength;
    mapping(bytes32 => uint256) public redemptionCountdowns;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    /// @dev Requires the sender to be the redemption admin multisig contract.
    modifier onlyRedemptionAdminMultiSig() {
        require(address(redemptionAdminMultiSig) == msg.sender);
        _;
    }

    /// @dev Requires the sender an owner of the redemptionAdminMultiSig
    modifier onlyRedemptionAdmin() {
        require(redemptionAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    /// @dev Requires the sender to be an owner of the SuperProtectorMultiSig
    modifier onlySuperProtectorMultiSig() {
        require(superProtectorMultiSig == (msg.sender));
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
    /// @param _redemptionAdminMultiSig Address of the redemption admin multisig contract.
    /// @param _assets Address of the assets contract.
    function initialize(
        IMultiSigWallet _redemptionAdminMultiSig,
        IMultiSigWallet _basicProtectorMultiSig,
        address _superProtectorMultiSig,
        Assets _assets,
        MPVToken _mpvToken,
        MasterPropertyValue _masterPropertyValue
    ) public initializer {
        redemptionAdminMultiSig = _redemptionAdminMultiSig;
        basicProtectorMultiSig = _basicProtectorMultiSig;
        superProtectorMultiSig = _superProtectorMultiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        masterPropertyValue = _masterPropertyValue;
        burningActionCountdownLength = 48 hours;
    }

    /// @dev Start the countdown to initiate burning of tokens. Transaction has
    /// to be sent by the redemption admin multisig.
    /// @param assetId Id of asset being redeemed.
    function startBurningCountdown(bytes32 assetId)
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
    function rejectRedemption(bytes32 assetId)
        public
        onlyRedemptionAdmin
        mpvNotPaused
    {
        assets.rejectRedemption(assetId);
        emit RedemptionRejected(msg.sender, assetId);
    }

    function executeRedemption(bytes32 assetId)
        public
    {
        require(
            redemptionAdminMultiSig.hasOwner(msg.sender) ||
            basicProtectorMultiSig.hasOwner(msg.sender)
        );
        require(
            now > redemptionCountdowns[assetId].add(burningActionCountdownLength)
        );

        (uint256 amount, ,) = assets.redemptionTokenLocks(assetId);
        assets.executeRedemption(assetId);
        mpvToken.burn(address(assets), amount);
    }

    /// @dev Set the countdown length for the action of burning of tokens.
    /// Transaction has to be sent by the super owner multisig.
    /// @param newCountdown New countdown length.
    function updateBurningActionCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperProtectorMultiSig
    mpvNotPaused
    {
        burningActionCountdownLength = newCountdown;
        emit BurningActionCountdownUpdated(msg.sender, newCountdown);
    }
}
