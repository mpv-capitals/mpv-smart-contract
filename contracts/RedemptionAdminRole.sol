pragma solidity ^0.5.1;

import "zos-lib/contracts/Initializable.sol";
import "./IMultiSigWallet.sol";
import "./BasicOwnerRole.sol";
import "./MPVToken.sol";
import "./Assets.sol";

/**
 * @title RedemptionAdminRole
 * @dev Redemption admin role contract.
 */
contract RedemptionAdminRole is Initializable {
    /*
     *  Events
     */
    event BurningCountdownStarted(
            address indexed sender,
            uint256 indexed assetId,
            uint256 indexed tokens
    );

    event RedemptionRejected(address indexed sender, uint256 indexed assetId);

    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    Assets public assets;
    uint256 public burningActionCountdownLength;
    mapping(uint256 => uint256) public redemptionCountdowns;

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

    /*
     * Public functions
     */
    /// @dev Initialize function sets initial storage values.
    /// @param _multiSig Address of the redemption admin multisig contract.
    /// @param _assets Address of the assets contract.
    function initialize(
        IMultiSigWallet _multiSig,
        Assets _assets
    ) public initializer {
        multiSig = _multiSig;
        assets = _assets;
        burningActionCountdownLength = 48 hours;
    }

    /// @dev Start the countdown to initiate burning of tokens. Transaction has
    /// to be sent by the redemption admin multisig.
    /// @param assetId Id of asset being redeemed.
    function startBurningCountdown(uint256 assetId)
        public
        onlyRedemptionAdminMultiSig
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
    {
        assets.rejectRedemption(assetId);
        emit RedemptionRejected(msg.sender, assetId);
    }
}
