pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./MultiSigWallet/MultiSigWallet.sol";
import "./IMultiSigWallet.sol";
import "./SafeMath.sol";
import "./Assets.sol";


contract MasterPropertyValue is Initializable {
    using Assets for Assets.State;
    using SafeMath for uint256;

    IMultiSigWallet public superOwnerMultiSig;
    IMultiSigWallet public basicOwnerMultiSig;
    IMultiSigWallet public operationAdminMultiSig;
    IMultiSigWallet public mintingAdminMultiSig;
    IMultiSigWallet public redemptionAdminMultiSig;

    Assets.State private assets;

    uint256 public superOwnerActionsThreshold;
    uint256 public basicOwnerActionsThreshold;
    uint256 public operationAdminActionsThreshold;
    uint256 public mintingAdminActionsThreshold;
    uint256 public redemptionAdminActionsThreshold;

    struct Asset {
        uint256 id;
        uint256 valuation;
        bytes32 fingerprint;
        uint256 tokens;
    }

    event LogAddSuperOwner(uint256 transactionId, address superOwner);
    event LogSuperOwnerAdded(address superOwner);
    event LogRemoveSuperOwner(uint256 transactionId, address superOwner);
    event LogSuperOwnerRemoved(address superOwner);

    event LogAddBasicOwner(uint256 transactionId, address basicOwner);
    event LogBasicOwnerAdded(address basicOwner);
    event LogRemoveBasicOwner(uint256 transactionId, address basicOwner);
    event LogBasicOwnerRemoved(address basicOwner);

    event LogAddOperationAdmin(uint256 transactionId, address operationAdmin);
    event LogOperationAdminAdded(address operationAdmin);
    event LogRemoveOperationAdmin(uint256 transactionId, address operationAdmin);
    event LogOperationAdminRemoved(address operationAdmin);

    event LogAddMintingAdmin(uint256 transactionId, address mintingAdmin);
    event LogMintingAdminAdded(address mintingAdmin);
    event LogRemoveMintingAdmin(uint256 transactionId, address mintingAdmin);
    event LogMintingAdminRemoved(address mintingAdmin);

    event LogAddRedemptionAdmin(uint256 transactionId, address redemptionAdmin);
    event LogRedemptionAdminAdded(address redemptionAdmin);
    event LogRemoveRedemptionAdmin(uint256 transactionId, address redemptionAdmin);
    event LogRedemptionAdminRemoved(address redemptionAdmin);

    event LogAddAsset(uint256 assetId);
    event LogRemoveAsset(uint256 assetId);

    function initialize(
      address _superOwnerMultiSig,
      address _basicOwnerMultiSig,
      address _operationAdminMultiSig,
      address _mintingAdminMultiSig,
      address _redemptionAdminMultiSig
    ) public initializer {
        superOwnerMultiSig = IMultiSigWallet(_superOwnerMultiSig);
        basicOwnerMultiSig = IMultiSigWallet(_basicOwnerMultiSig);
        operationAdminMultiSig = IMultiSigWallet(_operationAdminMultiSig);
        mintingAdminMultiSig = IMultiSigWallet(_mintingAdminMultiSig);
        redemptionAdminMultiSig = IMultiSigWallet(_redemptionAdminMultiSig);

        superOwnerActionsThreshold = 40;
        basicOwnerActionsThreshold = 100;
        operationAdminActionsThreshold = 100;
        mintingAdminActionsThreshold = 100;
        redemptionAdminActionsThreshold = 100;
    }

    modifier onlyMPV() {
        require(msg.sender == address(this));
        _;
    }

    modifier onlySuperOwnerMultiSig() {
        require(msg.sender == address(superOwnerMultiSig));
        _;
    }

    modifier onlySuperOwner() {
        require(_isOwner(superOwnerMultiSig, msg.sender));
        _;
    }

    modifier onlyBasicOwner() {
        require(_isOwner(basicOwnerMultiSig, msg.sender));
        _;
    }

    modifier onlyBasicOwnerMultiSig() {
        require(msg.sender == address(basicOwnerMultiSig));
        _;
    }

    modifier onlyOperationAdmin() {
        require(_isOwner(operationAdminMultiSig, msg.sender));
        _;
    }

    modifier onlyOperationAdminMultiSig() {
        require(msg.sender == address(operationAdminMultiSig));
        _;
    }

    modifier onlyMintingAdmin() {
        require(_isOwner(operationAdminMultiSig, msg.sender));
        _;
    }

    modifier onlyMintingAdminMultiSig() {
        require(msg.sender == address(mintingAdminMultiSig));
        _;
    }

    modifier onlyRedemptionAdmin() {
        require(_isOwner(redemptionAdminMultiSig, msg.sender));
        _;
    }

    modifier onlyRedemptionAdminMultiSig() {
        require(msg.sender == address(redemptionAdminMultiSig));
        _;
    }

    function addSuperOwner(address newSuperOwner)
      public
      onlySuperOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addSuperOwner.selector,
            newSuperOwner
        );

        transactionId = superOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogAddSuperOwner(transactionId, newSuperOwner);
    }

    function _addSuperOwner(address newSuperOwner)
        public
        onlySuperOwnerMultiSig()
    {
        superOwnerMultiSig.addOwner(newSuperOwner);
        _updateSuperOwnerRequirement();
        emit LogSuperOwnerAdded(newSuperOwner);
    }

    function removeSuperOwner(address superOwner)
      public
      onlySuperOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._removeSuperOwner.selector,
            superOwner
        );

        transactionId = superOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogRemoveSuperOwner(transactionId, superOwner);
    }

    function _removeSuperOwner(address superOwner)
        public
        onlySuperOwnerMultiSig()
    {
        superOwnerMultiSig.removeOwner(superOwner);
        _updateSuperOwnerRequirement();
        emit LogSuperOwnerRemoved(superOwner);
    }

    function addBasicOwner(address newBasicOwner)
      public
      onlySuperOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addBasicOwner.selector,
            newBasicOwner
        );

        transactionId = superOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogAddBasicOwner(transactionId, newBasicOwner);
    }

    function _addBasicOwner(address newBasicOwner)
        public
        onlySuperOwnerMultiSig()
    {
        basicOwnerMultiSig.addOwner(newBasicOwner);
        _updateBasicOwnerRequirement();
        emit LogBasicOwnerAdded(newBasicOwner);
    }

    function removeBasicOwner(address basicOwner)
      public
      onlySuperOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._removeBasicOwner.selector,
            basicOwner
        );

        transactionId = superOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogRemoveBasicOwner(transactionId, basicOwner);
    }

    function _removeBasicOwner(address basicOwner)
        public
        onlySuperOwnerMultiSig()
    {
        basicOwnerMultiSig.removeOwner(basicOwner);
        _updateBasicOwnerRequirement();
        emit LogBasicOwnerRemoved(basicOwner);
    }

    function addOperationAdmin(address newOperationAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addOperationAdmin.selector,
            newOperationAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogAddOperationAdmin(transactionId, newOperationAdmin);
    }

    function _addOperationAdmin(address newOperationAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        operationAdminMultiSig.addOwner(newOperationAdmin);
        _updateOperationAdminRequirement();
        emit LogOperationAdminAdded(newOperationAdmin);
    }

    function removeOperationAdmin(address operationAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._removeOperationAdmin.selector,
            operationAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogRemoveOperationAdmin(transactionId, operationAdmin);
    }

    function _removeOperationAdmin(address operationAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        operationAdminMultiSig.removeOwner(operationAdmin);
        _updateOperationAdminRequirement();
        emit LogOperationAdminRemoved(operationAdmin);
    }

    function addMintingAdmin(address newMintingAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addMintingAdmin.selector,
            newMintingAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogAddMintingAdmin(transactionId, newMintingAdmin);
    }

    function _addMintingAdmin(address newMintingAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        mintingAdminMultiSig.addOwner(newMintingAdmin);
        _updateMintingAdminRequirement();
        emit LogMintingAdminAdded(newMintingAdmin);
    }

    function removeMintingAdmin(address mintingAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._removeMintingAdmin.selector,
            mintingAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogRemoveMintingAdmin(transactionId, mintingAdmin);
    }

    function _removeMintingAdmin(address mintingAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        mintingAdminMultiSig.removeOwner(mintingAdmin);
        _updateMintingAdminRequirement();
        emit LogMintingAdminRemoved(mintingAdmin);
    }

    function addRedemptionAdmin(address newRedemptionAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addRedemptionAdmin.selector,
            newRedemptionAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogAddRedemptionAdmin(transactionId, newRedemptionAdmin);
    }

    function _addRedemptionAdmin(address newRedemptionAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        redemptionAdminMultiSig.addOwner(newRedemptionAdmin);
        _updateRedemptionAdminRequirement();
        emit LogRedemptionAdminAdded(newRedemptionAdmin);
    }

    function removeRedemptionAdmin(address redemptionAdmin)
      public
      onlyBasicOwner()
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._removeRedemptionAdmin.selector,
            redemptionAdmin
        );

        transactionId = basicOwnerMultiSig.mpvSubmitTransaction(
            address(this), 0, data);
        emit LogRemoveRedemptionAdmin(transactionId, redemptionAdmin);
    }

    function _removeRedemptionAdmin(address redemptionAdmin)
        public
        onlyBasicOwnerMultiSig()
    {
        redemptionAdminMultiSig.removeOwner(redemptionAdmin);
        _updateRedemptionAdminRequirement();
        emit LogRedemptionAdminRemoved(redemptionAdmin);
    }

    function _updateSuperOwnerRequirement()
        internal
        onlySuperOwnerMultiSig() {
        _updateRequirement(superOwnerMultiSig, superOwnerActionsThreshold);
    }

    function _updateBasicOwnerRequirement()
        internal
        onlySuperOwnerMultiSig() {
        _updateRequirement(basicOwnerMultiSig, basicOwnerActionsThreshold);
    }

    function _updateOperationAdminRequirement()
        internal
        onlyBasicOwnerMultiSig() {
        _updateRequirement(operationAdminMultiSig, operationAdminActionsThreshold);
    }

    function _updateMintingAdminRequirement()
        internal
        onlyBasicOwnerMultiSig() {
        _updateRequirement(mintingAdminMultiSig, mintingAdminActionsThreshold);
    }

    function _updateRedemptionAdminRequirement()
        internal
        onlyBasicOwnerMultiSig() {
        _updateRequirement(redemptionAdminMultiSig, redemptionAdminActionsThreshold);
    }

    // updateRequirements updates the requirement property in the multsig.
    // The value is calculate post addition/removal of owner and based on
    // the threshold value for that multisig set by MPV.
    function _updateRequirement(
        IMultiSigWallet multiSig,
        uint256 threshold
    )
    internal {
        uint256 totalOwners = multiSig.getOwners().length;
        uint256 votesRequired = (
            threshold.mul(totalOwners)
        ).div(100);

        if (votesRequired == 0) {
            votesRequired = 1;
        }

        multiSig.changeRequirement(votesRequired);
    }

    function isSuperOwner(address superOwner)
      public
      returns (bool) {
        return _isOwner(superOwnerMultiSig, superOwner);
    }

    function isBasicOwner(address basicOwner)
      public
      returns (bool) {
        return _isOwner(basicOwnerMultiSig, basicOwner);
    }

    function isOperationAdmin(address operationAdmin)
      public
      returns (bool) {
        return _isOwner(operationAdminMultiSig, operationAdmin);
    }

    function isMintingAdmin(address mintingAdmin)
      public
      returns (bool) {
        return _isOwner(mintingAdminMultiSig, mintingAdmin);
    }

    function isRedemptionAdmin(address redemptionAdmin)
      public
      returns (bool) {
        return _isOwner(redemptionAdminMultiSig, redemptionAdmin);
    }

    function _isOwner(IMultiSigWallet multiSig, address owner)
      internal
      returns (bool) {
        return multiSig.hasOwner(owner);
    }

    // getSuperOwners returns super owners
    function getSuperOwners()
      public
      returns (address[] memory) {
        return _getOwners(superOwnerMultiSig);
    }

    function getBasicOwners()
      public
      returns (address[] memory) {
        return _getOwners(basicOwnerMultiSig);
    }

    function getOperationAdmins()
      public
      returns (address[] memory) {
        return _getOwners(operationAdminMultiSig);
    }

    function getMintingAdmins()
      public
      returns (address[] memory) {
        return _getOwners(mintingAdminMultiSig);
    }

    function getRedemptionAdmins()
      public
      returns (address[] memory) {
        return _getOwners(redemptionAdminMultiSig);
    }

    function _getOwners(IMultiSigWallet multiSig)
      internal
      returns (address[] memory) {
        return multiSig.getOwners();
    }

    // addAsset adds an asset
    function addAsset(Asset memory _asset)
      public
      onlySuperOwner() {
        Assets.Asset memory asset;
        asset.id = _asset.id;
        asset.valuation = _asset.valuation;
        asset.fingerprint = _asset.fingerprint;
        asset.tokens = _asset.tokens;
        asset.status = Assets.Status.PENDING;
        asset.timestamp = now;
        assets.add(asset);
        emit LogAddAsset(asset.id);
    }

    // addAssets adds a list of assets
    function addAssets(Asset[] memory _assets)
      public
      onlySuperOwner() {
        for (uint256 i = 0; i < _assets.length; i++) {
            addAsset(_assets[i]);
        }
    }

    // getAsset returns asset
    function getAsset(uint256 id)
      public
      returns (Assets.Asset memory) {
        return assets.get(id);
    }
}
