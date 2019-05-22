pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";
import "./MasterPropertyValue.sol";
import "./IMultiSigWallet.sol";
import "./Assets.sol";
import "./MPVToken.sol";
import "./SuperOwnerRole.sol";
import "./BasicOwnerRole.sol";


/**
 * @title MintingAdminRole
 * @dev Minting admin role contract.
 */
contract MintingAdminRole is Initializable {
    using SafeMath for uint256;

    /*
     *  Events
     */
    event MintingCancelled(address indexed sender);
    event MintingReceiverWalletUpdated(address indexed sender, address indexed wallet);
    event MintingCountdownStarted(address indexed sender);
    event RefreshPendingAssetsStatus(address indexed sender);
    event PendingAssetAdded(address indexed sender, uint256 indexed assetId);
    event PendingAssetRemoved(address indexed sender, uint256 indexed assetId);
    event AssetEnlisted(address indexed sender, uint256 indexed assetId);

    /*
     *  Storage
     */
    IMultiSigWallet public multiSig;
    Assets public assets;
    MPVToken public mpvToken;
    SuperOwnerRole public superOwnerRole;
    BasicOwnerRole public basicOwnerRole;
    address public mintingReceiverWallet;
    uint256 public mintingActionCountdownLength;
    uint256 public mintingCountdownStart;
    uint256 public pendingAssetsTransactionId;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    modifier onlyMultiSig() {
        require(address(multiSig) == msg.sender);
        _;
    }

    modifier onlyOwner() {
        require(multiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicOwner() {
        require(IMultiSigWallet(basicOwnerRole.multiSig()).hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicOwnerMultiSig() {
        require(address(basicOwnerRole.multiSig()) == msg.sender);
        _;
    }

    modifier onlySuperOwnerMultiSig() {
        require(address(superOwnerRole.multiSig()) == msg.sender);
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
    /// @param _multiSig Address of the minting owner multisig contract.
    /// @param _assets Address of the Assets contrac.
    /// @param _mpvToken Address of the MPV Token contract.
    /// @param _superOwnerRole Address of the super owner role contract.
    /// @param _basicOwnerRole Address of the basic owner role contract.
    /// @param _mintingReceiverWallet Address of the new token minting receiving wallet.
    function initialize(
        IMultiSigWallet _multiSig,
        Assets _assets,
        MPVToken _mpvToken,
        SuperOwnerRole _superOwnerRole,
        BasicOwnerRole _basicOwnerRole,
        address _mintingReceiverWallet,
        MasterPropertyValue _masterPropertyValue
    ) public initializer {
        multiSig = _multiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        masterPropertyValue = _masterPropertyValue;
        superOwnerRole = _superOwnerRole;
        basicOwnerRole = _basicOwnerRole;
        mintingReceiverWallet = _mintingReceiverWallet;
        mintingActionCountdownLength = 48 hours;
    }

    /// @dev Set minting action countdown length.
    /// @param newCountdown New countdown length.
    function updateMintingActionCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    mpvNotPaused
    {
        mintingActionCountdownLength = newCountdown;
    }

    /// @dev Add asset to list of pending assets. Submits a multisig
    /// transaction and returns the transaction id. Transaction has to be
    /// sent by a minting admin.
    /// @param _asset Asset to add as pending.
    /// @return Returns transaction ID.
    function addPendingAsset(Assets.Asset memory _asset)
    public
    onlyOwner
    mpvNotPaused
    returns (uint256) {
        // minting countdown terminated
        require(mintingCountdownStart == 0);

        // Check if there's a transaction id active of if there's pending assets.
        // The first check is required in case the transaction id is actually 0.
        if (!(assets.pendingAssetsCount() > 0 || pendingAssetsTransactionId != 0)) {
            assets.addPendingAsset(_asset);
            bytes memory data = abi.encodeWithSelector(
                this._startMintingCountdown.selector
            );

            uint256 transactionId = multiSig.addTransaction(address(this), data);
            pendingAssetsTransactionId = transactionId;
            emit PendingAssetAdded(msg.sender, _asset.id);
            return transactionId;
        } else {
            assets.addPendingAsset(_asset);
            multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
            emit PendingAssetAdded(msg.sender, _asset.id);
            return pendingAssetsTransactionId;
        }
    }

    /// @dev Add a list of assets to list of pending assets. Submits a multisig
    /// transaction and returns the transaction id. Transaction has to be sent
    /// by a minting admin.
    /// @param _assets List of assets to add as pending.
    /// @return Returns transaction ID.
    function addPendingAssets(Assets.Asset[] memory _assets)
    public
    onlyOwner
    mpvNotPaused
    returns (uint256) {
        for (uint256 i = 0; i < _assets.length; i++) {
            addPendingAsset(_assets[i]);
        }

        return pendingAssetsTransactionId;
    }

    /// @dev Starts the minting countdown period. Transaction has to be sent
    /// by the minting admin multsig contract.
    function _startMintingCountdown()
    public
    onlyMultiSig
    mpvNotPaused
    {
        require(mintingCountdownStart == 0);
        mintingCountdownStart = now;
        emit MintingCountdownStarted(msg.sender);
    }

    /// @dev Refreshes the status of pending assets. Transaction can be sent
    /// by anyone.
    function refreshPendingAssetsStatus()
    public
    {
        require(now >= mintingCountdownStart.add(mintingActionCountdownLength));
        _enlistPendingAssets();
        emit RefreshPendingAssetsStatus(msg.sender);
    }

    /// @dev Removes an asset from the list of pending assets. This actions
    /// resets all confirmations. Transaction has to be sent by a minting admin.
    /// @param assetId Id of asset to remove from the pending list.
    /// @return Returns transaction ID.
    function removePendingAsset(uint256 assetId)
    public
    onlyOwner
    mpvNotPaused
    returns (uint256)
    {
        assets.removePendingAsset(assetId);

        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        emit PendingAssetRemoved(msg.sender, assetId);
        return pendingAssetsTransactionId;
    }

    /// @dev Allows a basic owner to cancel the minting process. Transaction has
    /// to be sent the by the basic owner role contract.
    function cancelMinting()
    public
    onlyBasicOwner
    mpvNotPaused
    {
        require(mintingCountdownStart > 0);
        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        mintingCountdownStart = 0;
        emit MintingCancelled(msg.sender);
    }

    /// @dev Set the receiver wallet of newly minting tokens. Transaction has
    /// to be sent by the basic owner multisig contract.
    /// @param newWallet Address of new wallet.
    function updateMintingReceiverWallet(
        address newWallet
    )
    public
    onlyBasicOwnerMultiSig
    mpvNotPaused
    {
        require(newWallet != address(0));
        mintingReceiverWallet = newWallet;
        emit MintingReceiverWalletUpdated(msg.sender, newWallet);
    }

    /*
     * Internal functions
     */
    /// @dev Set the assets in the pending list as enlisted.
    function _enlistPendingAssets()
    internal {
        Assets.Asset[] memory _assets = assets.getPendingAssets();
        for (uint256 i = 0; i < _assets.length; i++) {
            _enlistPendingAsset(_assets[i]);
        }

        /// reset pending assets
        pendingAssetsTransactionId = 0;
        assets.clearPendingAssets();
        mintingCountdownStart = 0;
    }

    /// @dev Set an asset as pending and adding it to the Assets contract.
    /// @param asset Asset to enlist.
    function _enlistPendingAsset(Assets.Asset memory asset)
    internal {
        asset.status = Assets.Status.Enlisted;
        assets.add(asset);
        mpvToken.mint(mintingReceiverWallet, asset.tokens);
        emit AssetEnlisted(msg.sender, asset.id);
    }
}
