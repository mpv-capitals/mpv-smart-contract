pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "./MPVToken.sol";
import "./IMultiSigWallet.sol";
import "./RedemptionAdminRole.sol";


/**
 * @title Assets
 * @dev Contract for managing assets.
 */
contract Assets is Initializable {
    using SafeMath for uint256;

    /*
     *  Events
     */
    event RedemptionFeeUpdated(address indexed sender, uint256 indexed fee);

    event RedemptionFeeReceiverWalletUpdated(
        address indexed sender,
        address indexed fee
    );

    event AssetAdded(
        address indexed sender,
        uint256 indexed assetId,
        Status indexed status,
        bytes32 notarizationId,
        uint256 tokens,
        uint256 timstamp
    );

    event PendingAssetAdded(address indexed sender, uint256 indexed assetId);
    event PendingAssetRemoved(address indexed sender, uint256 indexed assetId);
    event PendingAssetsCleared(address indexed sender);
    event AssetMarkedReserved(address indexed sender, uint256 indexed assetId);
    event AssetMarkedEnlisted(address indexed sender, uint256 indexed assetId);

    event RedemptionRequested(
        uint256 assetId,
        address account,
        uint256 burnAmount,
        uint256 redemptionFee,
        uint256 transactionId
    );

    event RedemptionCancelled(
        uint256 assetId,
        address account,
        uint256 refundAmount
    );

    event RedemptionRejected(uint256 assetId, address account, uint256 refundAmount);
    event RedemptionExecuted(uint256 assetId, address account, uint256 assetValue);

    /*
     *  Storage
     */
    mapping (uint256 => Asset) public assets;
    mapping (uint256 => RedemptionTokenLock) public redemptionTokenLocks;
    Asset[] public pendingAssets;
    uint256 public pendingAssetsTransactionId;
    uint256 public redemptionFee;
    address public redemptionFeeReceiverWallet;
    address public mintingAdminRole;
    RedemptionAdminRole public redemptionAdminRole;
    address public superOwnerMultiSig;
    IMultiSigWallet public basicOwnerMultiSig;
    IMultiSigWallet public redemptionMultiSig;
    MPVToken public mpvToken;
    mapping (uint256 => uint256) public totalMinted;

    /// @dev Asset is the structure for an asset.
    struct Asset {
        /// @dev id is asset id.
        uint256 id;

        /// @dev status is current state asset is in.
        Status status;

        /// @dev fingerprint is the content hash of the certificate file.
        bytes32 notarizationId;

        /// @dev tokens is how many tokens are required to redeem this asset.
        uint256 tokens;

        /// @dev owner is the redeemer of the asset.
        address owner;

        /// @dev timestamp is the date the asset was added.
        uint256 timestamp;
    }

    /// @dev Asset is the structure for a redemption request locking of tokens.
    struct RedemptionTokenLock {
        /// @dev amount is the amount of tokens locked.
        uint256 amount;

        /// @dev amount is the amount of tokens locked.
        address account;

        /// @dev transactionId is the transaction id of the redemption request.
        /// redemption admins confirm this transaction id.
        uint256 transactionId;
    }

    // @dev Status is an enum representing the possible states for an asset.
    enum Status {
        /// @dev Pending is when the asset has been newly added and is
        /// pending approval by minting admins. Pending is the default state.
        Pending,

        /// @dev Enlisted is when the asset has been approved and added by minting admins.
        Enlisted,

        /// @dev Locked is when the asset process for redemption has been started.
        Locked,

        /// @dev Redeemed is when the asset has been redeemed by a user.
        Redeemed,

        /// @dev Reserved is when the asset is temporarily reserved from redemption.
        Reserved
    }

    /*
     *  Modifiers
     */
    /// @dev Requires that the sender is the minting admin role contract.
    modifier onlyMintingAdminRole() {
        require(mintingAdminRole == msg.sender);
        _;
    }

    /// @dev Requires that the sender is the redemption admin role contract.
    modifier onlyRedemptionAdminRole() {
        require(address(redemptionAdminRole) == msg.sender);
        _;
    }

    /// @dev Requires that the sender is the basic owner multisig contract.
    modifier onlyBasicOwnerMultiSig() {
        require(address(basicOwnerMultiSig) == msg.sender);
        _;
    }

    /*
     * Public functions
     */
    /// @dev Initialize function set initial storage values.
    /// @param _redemptionFee Initial fee required for redeeming an asset.
    /// @param _redemptionFeeReceiverWallet Initial wallet that receives
    /// the redemption fees.
    /// @param _mintingAdminRole Address of the minting admin role contract.
    /// @param _redemptionAdminRole Address of the redemption admin Role contract.
    /// @param _redemptionMultiSig Address of the redemption admin multisig contract.
    /// @param _basicOwnerMultiSig Address of the basic owner multisig contract.
    /// @param _mpvToken Address of the MPV Token contract.
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

    /// @dev Set the redemption fee amount. Transaction has to be sent by
    /// the basic owner multisig contract.
    /// @param fee New fee amount.
    function setRedemptionFee(uint256 fee)
    public
    onlyBasicOwnerMultiSig
    {
        redemptionFee = fee;
        emit RedemptionFeeUpdated(msg.sender, fee);
    }

    /// @dev Set the redemption fee receiver wallet address. Transaction has
    /// to be sent by the basic owner multisig contract.
    /// @param wallet Address of new wallet.
    function setRedemptionFeeReceiverWallet(address wallet)
    public
    onlyBasicOwnerMultiSig
    {
        require(wallet != address(0));
        redemptionFeeReceiverWallet = wallet;
        emit RedemptionFeeReceiverWalletUpdated(msg.sender, wallet);
    }

    /// @dev Add a new asset to the assets map. Transaction has to be sent by
    /// the minting admin role contract.
    /// @param asset Asset to add.
    function add(Asset memory asset)
    public
    onlyMintingAdminRole
    {
        require(assets[asset.id].id == 0);
        assets[asset.id] = asset;
        _incrementTotalMintedCount(asset.status, asset.tokens);
        emit AssetAdded(
            msg.sender,
            asset.id,
            asset.status,
            asset.notarizationId,
            asset.tokens,
            asset.timestamp
        );
    }

    /// @dev Get an asset given the asset id. Transaction can be called by anyone.
    /// @param id Id of asset.
    /// @return Returns the asset parameters.
    function get(uint256 assetId) public returns (
        uint256 id,
        Status status,
        bytes32 notarizationId,
        uint256 tokens,
        address owner,
        uint256 timestamp
    ) {
        Asset storage asset = assets[assetId];
        id = asset.id;
        status = asset.status;
        notarizationId = asset.notarizationId;
        tokens = asset.tokens;
        owner = asset.owner;
        timestamp = timestamp;
    }

    function getRedemptionTokenLock(uint256 assetId) public returns (
        uint256 amount,
        address account,
        uint256 transactionId
    ) {
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];
        amount = tokenLock.amount;
        account = tokenLock.account;
        transactionId = tokenLock.transactionId;
    }

    /// @dev Add a list of a new assets to the assets map. Transaction has to
    /// be sent by the minting admin role contract.
    /// @param _assets List of assets to add.
    function addList(Asset[] memory _assets)
    public
    onlyMintingAdminRole
    {
        require(_assets.length > 0);

        for (uint256 i = 0; i < _assets.length; i++) {
            add(_assets[i]);
        }
    }

    /// @dev Add a new asset to the list of pending assets. Transaction has
    /// to be sent by the minting admin role contract.
    /// @param _asset Asset to add as pending.
    function addPendingAsset(Asset memory _asset)
    public
    onlyMintingAdminRole
    {
        pendingAssets.push(_asset);
        _incrementTotalMintedCount(_asset.status, _asset.tokens);
        emit PendingAssetAdded(msg.sender, _asset.id);
    }

    /// @dev Clear list of pending assets. Transaction has to be sent by the
    /// minting admin role contract.
    function clearPendingAssets()
    public
    onlyMintingAdminRole
    {

        for (uint256 i = 0; i < pendingAssets.length; i++) {
            _decrementTotalMintedCount(pendingAssets[i].status, pendingAssets[i].tokens);
        }

        delete pendingAssets;
        emit PendingAssetsCleared(msg.sender);
    }

    /// @dev Remove an asset from the list of pending assets. Transaction has
    /// to be sent by the minting admin role contract.
    /// @param assetId Id of asset to remove.
    function removePendingAsset(uint256 assetId)
    public
    onlyMintingAdminRole
    {
        for (uint256 i = 0; i < pendingAssets.length; i++) {
            if (pendingAssets[i].id == assetId) {
                _decrementTotalMintedCount(pendingAssets[i].status, pendingAssets[i].tokens);

                if (i >= pendingAssets.length) continue;
                // remove pending asset array item and shift items
                for (uint256 j = i; j < pendingAssets.length-1; j++) {
                    pendingAssets[j] = pendingAssets[j+1];
                }
                delete pendingAssets[pendingAssets.length-1];
                pendingAssets.length--;
                emit PendingAssetRemoved(msg.sender, assetId);
            }
        }
    }

    /// @dev Submit a request to redeem an asset. Sender needs to have the
    /// amount of tokens an asset is worth plus the redemption fee. The redemption
    /// fee is non-refundable. Transaction can be sent by anyone.
    /// @param assetId Id of asset to redeem.
    /// @return Returns transaction ID.
    function requestRedemption(uint256 assetId)
    public
    returns (uint256 transactionId)
    {
        Asset storage asset = assets[assetId];
        require(asset.status == Status.Enlisted);
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
        _decrementTotalMintedCount(asset.status, asset.tokens);
        asset.status = Assets.Status.Locked;
        _incrementTotalMintedCount(asset.status, asset.tokens);

        emit RedemptionRequested(assetId, msg.sender, asset.tokens, redemptionFee, transactionId);
    }

    /// @dev Cancel an asset redemption request. Locked tokens will be unlocked.
    /// Transaction has be sent by the redeemer of the asset.
    /// @param assetId Id of asset to cancel redemption of.
    function cancelRedemption(uint256 assetId)
    public {
        Asset storage asset = assets[assetId];
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];

        require(asset.status == Status.Locked);
        require(redemptionMultiSig.getConfirmationCount(tokenLock.transactionId) == 0);
        require(tokenLock.account == msg.sender);
        emit RedemptionCancelled(assetId, msg.sender, tokenLock.amount);
        _revokeRedemption(assetId);
    }

    /// @dev Reject an asset redemption request. Locked tokens will be unlocked.
    /// Transaction has be sent by a redemptionAdminRole owner.
    /// @param assetId Id of asset to cancel redemption of.
    function rejectRedemption(uint256 assetId)
    public
    onlyRedemptionAdminRole {
        Asset storage asset = assets[assetId];
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];

        require(asset.status == Status.Locked);
        emit RedemptionRejected(assetId, tokenLock.account, tokenLock.amount);
        _revokeRedemption(assetId);
    }

    function executeRedemption(uint256 assetId)
    public
    onlyRedemptionAdminRole
    {
        Asset storage asset = assets[assetId];
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];
        _decrementTotalMintedCount(asset.status, asset.tokens);
        asset.status = Status.Redeemed;
        _incrementTotalMintedCount(asset.status, asset.tokens);
        emit RedemptionExecuted(assetId, tokenLock.account, tokenLock.amount);
        delete redemptionTokenLocks[assetId];
    }

    /// @dev Sets a list of enlisted assets as reserved. Transaction has be sent by
    /// the basic owner multisig.
    /// @param assetIds List of asset Ids to set as reserved.
    function setReserved(uint256[] memory assetIds)
    public
    onlyBasicOwnerMultiSig
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            _setReserved(assetIds[i]);
        }
    }

    /// @dev Sets a list of reserved assets as enlisted. Transaction has be sent by
    /// the basic owner multisig.
    /// @param assetIds List of asset Ids to set as reserved.
    function setEnlisted(uint256[] memory assetIds)
    public
    onlyBasicOwnerMultiSig
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            _setEnlisted(assetIds[i]);
        }
    }

    /// @dev Get the count of pending assets. Transaction can be called by anyone.
    /// @return Returns the count of pending assets.
    function pendingAssetsCount() public returns (uint256) {
        return pendingAssets.length;
    }

    /// @dev Get the list of pending assets. Transaction can be called by anyone.
    /// @return Returns the list of pending assets.
    function getPendingAssets() public returns (Asset[] memory) {
        return pendingAssets;
    }

    /*
     * Internal functions
     */
    /// @dev Sets an enlisted asset as reserved.
    /// @param assetId Id of asset.
    function _setReserved(uint256 assetId)
    internal {
        require(assets[assetId].status == Status.Enlisted);
        _decrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        assets[assetId].status = Status.Reserved;
        _incrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        emit AssetMarkedReserved(msg.sender, assetId);
    }

    /// @dev Sets a reserved asset as enlisted.
    /// @param assetId Id of asset.
    function _setEnlisted(uint256 assetId)
    internal {
        require(assets[assetId].status == Status.Reserved);
        _decrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        assets[assetId].status = Status.Enlisted;
        _incrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        emit AssetMarkedEnlisted(msg.sender, assetId);
    }

    /// @dev sets asset.status back to Enlisted and refunds tokens to redeemer
    /// @param assetId Id of asset.
    function _revokeRedemption(uint256 assetId)
    internal
    {
        Asset storage asset = assets[assetId];
        RedemptionTokenLock storage tokenLock = redemptionTokenLocks[assetId];

        mpvToken.transfer(tokenLock.account, tokenLock.amount);
        _decrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        asset.status = Status.Enlisted;
        _incrementTotalMintedCount(assets[assetId].status, assets[assetId].tokens);
        delete redemptionTokenLocks[assetId];
    }

    function _decrementTotalMintedCount(Status status, uint256 amount)
    internal {
        uint256 k = uint256(status);
        totalMinted[k] = totalMinted[k].sub(amount);
    }

    function _incrementTotalMintedCount(Status status, uint256 amount)
    internal {
        uint256 k = uint256(status);
        totalMinted[k] = totalMinted[k].add(amount);
    }
}
