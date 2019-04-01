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
          uint256 id,
          Assets.Status status,
          bytes32 notarizationId,
          uint256 tokens,
          address owner,
          uint256 timestamp
        ) =  assets.get(assetId);

        require(status == Assets.Status.Locked);
        redemptionCountdowns[assetId] = now;
    }

    function rejectRedemption(uint256 assetId)
        public
        onlyRedemptionAdminOwner
    {
        assets.rejectRedemption(assetId);
    }
}
