pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./MPVToken.sol";


contract Assets is Initializable {
    using SafeMath for uint256;

    event RedemptionRequested(uint256 assetId, address account);

    // Asset is the structure for an asset.
    struct Asset {
        // id is asset ID.
        uint256 id;

        // status is current state asset is in.
        Status status;

        // fingerprint is the notarized certificate ID or hash.
        bytes32 notarizationId;

        // tokens is how many tokens are required to redeem this asset.
        uint256 tokens;

        // owner is the redeemer of the asset.
        address owner;

        // timestamp is the date the asset was added.
        uint256 timestamp;

        // statusEvents are a list of status changes that have occured. New events are appended.
        Status[] statusEvents;
    }

    // Status is the possible states for an asset.
    enum Status {
        // Pending is when the asset has been newly added and is pending approval by minting admins.
        // Pending is the default state.
        PENDING,

        // Enlisted is when the asset has been approved and added by minting admins.
        ENLISTED,

        // Locked is when the asset process for redemption has been started.
        LOCKED,

        // Redeemed is when the asset has been redeemed by a user.
        REDEEMED
    }

    mapping (uint256 => Asset) public assets;
    mapping (address => uint256) public redemptionTokenLocks;

    MPVToken mpvToken;

    uint256 public redemptionFee;
    address public redemptionFeeReceiverWallet;

    Asset[] public pendingAssets;
    uint256 public pendingAssetsTransactionId;

    function initialize(
        uint256 _redemptionFee,
        address _redemptionFeeReceiverWallet,
        MPVToken _mpvToken
    ) public initializer {
        require(_redemptionFeeReceiverWallet != address(0));
        redemptionFee = _redemptionFee;
        redemptionFeeReceiverWallet = _redemptionFeeReceiverWallet;
        mpvToken = _mpvToken;
    }

    // TODO
    function setRedemptionFee(uint256 fee) public {
        redemptionFee = fee;
    }

    function setRedemptionFeeReceiverWallet(address wallet)
    // TODO only super owner multisig
    public {
        require(wallet != address(0));
        redemptionFeeReceiverWallet = wallet;
    }

    // TODO
    function add(Asset memory asset) public {
        require(assets[asset.id].id == 0);
        assets[asset.id] = asset;
    }

    function get(uint256 id) public returns (Asset memory) {
        return assets[id];
    }

    // TODO
    function addList(Asset[] memory _assets) public {
        require(_assets.length > 0);

        for (uint256 i = 0; i < _assets.length; i++) {
            add(assets[i]);
        }
    }

    function pendingAssetsCount() public returns (uint256) {
        return pendingAssets.length;
    }

    function getPendingAssets() public returns (Asset[] memory) {
        return pendingAssets;
    }

    function addPendingAsset(Asset memory _asset) public {
        pendingAssets.push(_asset);
    }

    // TODO
    function resetPendingAssets() public {
        delete pendingAssets;
    }

    // TODO
    function removePendingAsset(uint256 assetId)
    public
    {
        for (uint256 i = 0; i < pendingAssets.length; i++) {
            if (pendingAssets[i].id == assetId) {
                if (i >= pendingAssets.length) continue;
                // remove pending asset array item and shift items
                for (uint256 j = i; j < pendingAssets.length-1; j++) {
                    pendingAssets[j] = pendingAssets[j+1];
                }
                delete pendingAssets[pendingAssets.length-1];
                pendingAssets.length--;
            }
        }
    }

    function requestRedemption(uint256 assetId) public {
        Asset storage asset = assets[assetId];
        require(asset.status == Status.ENLISTED);
        uint256 tokensRequired = asset.tokens.add(redemptionFee);

        require(mpvToken.transferFrom(msg.sender, address(this), asset.tokens));
        require(mpvToken.transferFrom(msg.sender, redemptionFeeReceiverWallet, redemptionFee));

        redemptionTokenLocks[msg.sender] = redemptionTokenLocks[msg.sender].add(asset.tokens);
        asset.status = Assets.Status.LOCKED;
        emit RedemptionRequested(assetId, msg.sender);
    }
}
