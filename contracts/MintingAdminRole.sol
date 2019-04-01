pragma solidity ^0.5.1;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
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

    modifier onlyBasicOwnerRole() {
        require(address(basicOwnerRole) == msg.sender);
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
        address _mintingReceiverWallet
    ) public initializer {
        multiSig = _multiSig;
        assets = _assets;
        mpvToken = _mpvToken;
        superOwnerRole = _superOwnerRole;
        basicOwnerRole = _basicOwnerRole;
        mintingReceiverWallet = _mintingReceiverWallet;
        mintingActionCountdownLength = 48 hours;
    }

    /// @dev Set minting action countdown length.
    /// @param newCountdown New countdown length.
    function setMintingActionCountdown(
        uint256 newCountdown
    )
    public
    onlySuperOwnerMultiSig
    {
        mintingActionCountdownLength = newCountdown;
    }

    /// @dev Add asset to list of pending assets. Submits a multisig transaction and returns the transaction id. Transaction has to be sent by a minting admin.
    /// @param _asset Asset to add as pending.
    /// @return Returns transaction ID.
    function addPendingAsset(Assets.Asset memory _asset)
    public
    onlyOwner
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
            return transactionId;
        } else {
            assets.addPendingAsset(_asset);
            multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
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
    {
        mintingCountdownStart = now;
    }

    /// @dev Refreshes the status of pending assets. Transaction can be sent
    /// by anyone.
    function refreshPendingAssetsStatus()
    public
    {
        require(now >= mintingCountdownStart + mintingActionCountdownLength);
        _enlistPendingAssets();
    }

    /// @dev Removes an asset from the list of pending assets. This actions
    /// resets all confirmations. Transaction has to be sent by a minting admin.
    /// @param assetId Id of asset to remove from the pending list.
    /// @return Returns transaction ID.
    function removePendingAsset(uint256 assetId)
    public
    onlyOwner
    returns (uint256)
    {
        assets.removePendingAsset(assetId);

        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        return pendingAssetsTransactionId;
    }

    /// @dev Allows a basic owner to cancel the minting process. Transaction has
    /// to be sent the by the basic owner role contract.
    function cancelMinting()
    public
    onlyBasicOwnerRole
    {
        require(mintingCountdownStart > 0);
        multiSig.revokeAllConfirmations(pendingAssetsTransactionId);
        mintingCountdownStart = 0;
    }

    /// @dev Set the receiver wallet of newly minting tokens. Transaction has
    /// to be sent by the basic owner multisig contract.
    /// @param newWallet Address of new wallet.
    function setMintingReceiverWallet(
        address newWallet
    )
    public
    onlyBasicOwnerMultiSig
    {
        require(newWallet != address(0));
        mintingReceiverWallet = newWallet;
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
    }
}
