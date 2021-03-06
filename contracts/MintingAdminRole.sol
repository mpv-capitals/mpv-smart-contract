pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "openzeppelin-eth/contracts/math/SafeMath.sol";
import "zos-lib/contracts/Initializable.sol";
import "./MasterPropertyValue.sol";
import "./IMultiSigWallet.sol";
import "./Assets.sol";
import "./MPVToken.sol";
import "./SuperProtectorRole.sol";
import "./BasicProtectorRole.sol";


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
    event PendingAssetAdded(address indexed sender, bytes32 indexed assetId);
    event PendingAssetRemoved(address indexed sender, bytes32 indexed assetId);
    event AssetEnlisted(address indexed sender, bytes32 indexed assetId);

    /*
     *  Storage
     */
    IMultiSigWallet public mintingAdminMultiSig;
    Assets public assets;
    MPVToken public mpvToken;
    SuperProtectorRole public superProtectorRole;
    BasicProtectorRole public basicProtectorRole;
    address public mintingReceiverWallet;
    uint256 public mintingActionCountdownLength;
    uint256 public mintingCountdownStart;
    uint256 public pendingAssetsTransactionId;
    MasterPropertyValue public masterPropertyValue;

    /*
     *  Modifiers
     */
    modifier onlyMintingAdminMultiSig() {
        require(address(mintingAdminMultiSig) == msg.sender);
        _;
    }

    modifier onlyMintingAdmin() {
        require(mintingAdminMultiSig.hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicProtector() {
        require(IMultiSigWallet(basicProtectorRole.basicProtectorMultiSig()).hasOwner(msg.sender));
        _;
    }

    modifier onlyBasicProtectorMultiSig() {
        require(address(basicProtectorRole.basicProtectorMultiSig()) == msg.sender);
        _;
    }

    modifier onlySuperProtectorMultiSig() {
        require(address(superProtectorRole.superProtectorMultiSig()) == msg.sender);
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
    /// @param _mintingAdminMultiSig Address of the minting owner multisig contract.
    /// @param _assets Address of the Assets contrac.
    /// @param _mpvToken Address of the MPV Token contract.
    /// @param _superProtectorRole Address of the super owner role contract.
    /// @param _basicProtectorRole Address of the basic owner role contract.
    /// @param _mintingReceiverWallet Address of the new token minting receiving wallet.
    function initialize(
        IMultiSigWallet _mintingAdminMultiSig,
        Assets _assets,
        MPVToken _mpvToken,
        SuperProtectorRole _superProtectorRole,
        BasicProtectorRole _basicProtectorRole,
        address _mintingReceiverWallet,
        MasterPropertyValue _masterPropertyValue
    ) public initializer {
        mintingAdminMultiSig = _mintingAdminMultiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        masterPropertyValue = _masterPropertyValue;
        superProtectorRole = _superProtectorRole;
        basicProtectorRole = _basicProtectorRole;
        mintingReceiverWallet = _mintingReceiverWallet;
        mintingActionCountdownLength = 48 hours;
    }

    /// @dev Set minting action countdown length.
    /// @param newCountdown New countdown length.
    function updateMintingActionCountdownLength(
        uint256 newCountdown
    )
    public
    onlySuperProtectorMultiSig
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
    onlyMintingAdmin
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

            uint256 transactionId = mintingAdminMultiSig.addTransaction(address(this), data);
            pendingAssetsTransactionId = transactionId;
            emit PendingAssetAdded(msg.sender, _asset.id);
            return transactionId;
        } else {
            assets.addPendingAsset(_asset);
            mintingAdminMultiSig.revokeAllConfirmations(pendingAssetsTransactionId);
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
    onlyMintingAdmin
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
    onlyMintingAdminMultiSig
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
    function removePendingAsset(bytes32 assetId)
    public
    onlyMintingAdmin
    mpvNotPaused
    returns (uint256)
    {
        assets.removePendingAsset(assetId);

        mintingAdminMultiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        emit PendingAssetRemoved(msg.sender, assetId);
        return pendingAssetsTransactionId;
    }

    /// @dev Allows a basic owner to cancel the minting process. Transaction has
    /// to be sent the by the basic owner role contract.
    function cancelMinting()
    public
    onlyBasicProtector
    mpvNotPaused
    {
        require(mintingCountdownStart > 0);
        mintingAdminMultiSig.revokeAllConfirmations(pendingAssetsTransactionId);
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
    onlyBasicProtectorMultiSig
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
