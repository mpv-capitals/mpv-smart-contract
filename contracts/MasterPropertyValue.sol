pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./MultiSigWallet/MultiSigWallet.sol";
import "./IMultiSigWallet.sol";
import "./SafeMath.sol";
import "./Roles.sol";
import "./Polls.sol";
import "./Assets.sol";

contract MasterPropertyValue is Initializable {
    using Assets for Assets.State;
    using SafeMath for uint256;
    using Roles for Roles.Role;
    using Polls for Polls.Poll;

    IMultiSigWallet public superOwners;
    Polls.Poll private polls;
    Assets.State private assets;

    uint256 public superOwnerActionsThreshold;

    struct Asset {
        uint256 id;
        uint256 valuation;
        bytes32 fingerprint;
        uint256 tokens;
    }

    event LogAddOwner(bytes32 key);
    event LogAddAsset(uint256 id);

    function initialize(
      address _superOwnersMultiSig
    ) public initializer {
      superOwners = IMultiSigWallet(_superOwnersMultiSig);

      superOwnerActionsThreshold = 40;
    }

    modifier onlyMPV() {
        require(msg.sender == address(this));
        _;
    }

    modifier onlySuperOwnerMultiSig() {
        require(msg.sender == address(superOwners));
        _;
    }

    modifier onlySuperOwner() {
        require(superOwners.hasOwner(msg.sender));
        _;
    }

    function _addSuperOwner(address owner)
        public
        onlySuperOwnerMultiSig
    {
        superOwners.addOwner(owner);

        uint256 totalOwners = superOwners.getOwners().length;
        uint256 votesRequired = (superOwnerActionsThreshold.mul(totalOwners)).div(100);

        if (votesRequired == 0) {
            votesRequired = 1;
        }

        superOwners.changeRequirement(votesRequired);
    }

    function addSuperOwner(address owner)
      public
      onlySuperOwner
      returns(uint256 transactionId) {
        bytes memory data = abi.encodeWithSelector(
            this._addSuperOwner.selector,
            owner
        );

        return superOwners.mpvSubmitTransaction(address(this), 0, data);
    }

    function isSuperOwner(address owner)
      public
      returns (bool) {
        return superOwners.hasOwner(owner);
    }

    // getSuperOwners returns super owners
    function getSuperOwners()
      public
      returns (address[] memory) {
        return superOwners.getOwners();
    }

    function execute(uint256 transactionId)
      public {
        superOwners.executeTransaction(transactionId);
    }

    // addAsset adds an asset
    function addAsset(Asset memory _asset)
      public
      onlySuperOwner {
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
      onlySuperOwner {
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
