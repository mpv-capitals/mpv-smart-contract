pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./MPVToken.sol";
import "./IMultiSigWallet.sol";
import "./RedemptionAdminRole.sol";


contract Assets is Initializable {
    using SafeMath for uint256;

    event RedemptionRequested(uint256 assetId, address account, uint256 burnAmount, uint256 redemptionFee, uint256 transactionId);
    event RedemptionCancelled(uint256 assetId, address account, uint256 refundAmount);

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

    struct RedemptionTokenLock {
        uint256 amount;
        address account;
        uint256 transactionId;
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
        REDEEMED,

        // Reserved is when the asset is temporarily reserved from redemption.
        RESERVED
    }

    mapping (uint256 => Asset) public assets;
    mapping (uint256 => RedemptionTokenLock) public redemptionTokenLocks;

    MPVToken mpvToken;

    uint256 public redemptionFee;
    address public redemptionFeeReceiverWallet;
    RedemptionAdminRole public redemptionAdminRole;
    IMultiSigWallet public redemptionMultiSig;

    Asset[] public pendingAssets;
    uint256 public pendingAssetsTransactionId;

    address public superOwnerMultiSig;
    address public mintingAdminRole;
    IMultiSigWallet public basicOwnerMultiSig;

    modifier onlyMintingAdminRole() {
        require(mintingAdminRole == msg.sender);
        _;
    }

    modifier onlyBasicOwnerMultiSig() {
        require(address(basicOwnerMultiSig) == msg.sender);
        _;
    }

    function initialize(
        uint256 _redemptionFee,
        address _redemptionFeeReceiverWallet,
        address _mintingAdminRole,
        RedemptionAdminRole _redemptionAdminRole,
        IMultiSigWallet _redemptionMultiSig,
        IMultiSigWallet _basicOwnerMultiSig,
        MPVToken _mpvToken
    ) public initializer {
        require(_redemptionFeeReceiverWallet != address(0));
        redemptionFee = _redemptionFee;
        redemptionFeeReceiverWallet = _redemptionFeeReceiverWallet;
        mintingAdminRole = _mintingAdminRole;
        redemptionAdminRole = _redemptionAdminRole;
        redemptionMultiSig = _redemptionMultiSig;
        basicOwnerMultiSig = _basicOwnerMultiSig;
        mpvToken = _mpvToken;
    }

    function setRedemptionFee(uint256 fee)
    public
    onlyBasicOwnerMultiSig
    {
        redemptionFee = fee;
    }

    function setRedemptionFeeReceiverWallet(address wallet)
    public
    onlyBasicOwnerMultiSig
    {
        require(wallet != address(0));
        redemptionFeeReceiverWallet = wallet;
    }

    function add(Asset memory asset)
    onlyMintingAdminRole
    public
    {
        require(assets[asset.id].id == 0);
        assets[asset.id] = asset;
    }

    function get(uint256 id) public returns (Asset memory) {
        return assets[id];
    }

    function addList(Asset[] memory _assets)
    public
    onlyMintingAdminRole
    {
        require(_assets.length > 0);

        for (uint256 i = 0; i < _assets.length; i++) {
            add(assets[i]);
        }
    }

    function addPendingAsset(Asset memory _asset)
    public
    onlyMintingAdminRole
    {
        pendingAssets.push(_asset);
    }

    function resetPendingAssets()
    public
    onlyMintingAdminRole
    {
        delete pendingAssets;
    }

    function removePendingAsset(uint256 assetId)
    public
    onlyMintingAdminRole
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

    function requestRedemption(uint256 assetId)
    public returns (uint256 transactionId)
    {
        Asset storage asset = assets[assetId];
        require(asset.status == Status.ENLISTED);
        require(mpvToken.transferFrom(msg.sender, address(this), asset.tokens));

        if (redemptionFee > 0) {
            require(mpvToken.transferFrom(msg.sender, redemptionFeeReceiverWallet, redemptionFee));
        }

        bytes memory data = abi.encodeWithSelector(
            redemptionAdminRole.startBurningCountdown.selector,
            assetId
        );
        transactionId = redemptionMultiSig.addTransaction(address(redemptionAdminRole), data);

        redemptionTokenLocks[assetId] = RedemptionTokenLock(asset.tokens, msg.sender, transactionId);
        asset.status = Assets.Status.LOCKED;

        emit RedemptionRequested(assetId, msg.sender, asset.tokens, redemptionFee, transactionId);
    }

    function cancelRedemption(uint256 assetId) public {
        Asset storage asset = assets[assetId];
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];

        require(asset.status == Status.LOCKED);
        require(redemptionMultiSig.getConfirmationCount(tokenLock.transactionId) == 0);
        require(tokenLock.account == msg.sender);

        mpvToken.transfer(msg.sender, tokenLock.amount);
        asset.status = Status.ENLISTED;
        emit RedemptionCancelled(assetId, msg.sender, tokenLock.amount);
        delete redemptionTokenLocks[assetId];
    }

    function setReserved(uint256[] memory assetIds)
    public
    onlyBasicOwnerMultiSig
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            _setReserved(assetIds[i]);
        }
    }

    function _setReserved(uint256 assetId)
    internal
    {
       require(assets[assetId].status == Status.ENLISTED);
       assets[assetId].status = Status.RESERVED;
    }

    function setEnlisted(uint256[] memory assetIds)
    public
    onlyBasicOwnerMultiSig
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            _setEnlisted(assetIds[i]);
        }
    }

    function _setEnlisted(uint256 assetId)
    internal
    {
       require(assets[assetId].status == Status.RESERVED);
       assets[assetId].status = Status.ENLISTED;
    }

    function pendingAssetsCount() public returns (uint256) {
        return pendingAssets.length;
    }

    function getPendingAssets() public returns (Asset[] memory) {
        return pendingAssets;
    }
}
