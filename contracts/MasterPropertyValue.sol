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

    IMultiSigWallet owners;
    Polls.Poll private polls;
    Assets.State private assets;

    struct Asset {
        uint256 id;
        uint256 valuation;
        bytes32 fingerprint;
        uint256 tokens;
    }

    event LogAddOwner(bytes32 key);
    event LogAddAsset(uint256 id);

    function initialize(
      address _owners
    ) public initializer {
      owners = IMultiSigWallet(_owners);
    }

    modifier onlySelf {
        require(msg.sender == address(this));
        _;
    }

    modifier onlyOwner {
        require(owners.hasOwner(msg.sender));
        _;
    }

    function addOwner(address owner) public onlyOwner returns(uint256) {
        bytes memory data = abi.encodeWithSelector(
            owners.addOwner.selector,
            owner
        );

        return owners.submitTransaction(address(owners), 0, data);
    }

    function isOwner(address owner) public returns (bool) {
        return owners.hasOwner(owner);
    }

    function execute(uint256 transactionId) public {
        owners.executeTransaction(transactionId);
    }

    // addAsset adds an asset
    function addAsset(Asset memory _asset) public onlyOwner {
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
    function addAssets(Asset[] memory _assets) public onlyOwner {
        for (uint256 i = 0; i < _assets.length; i++) {
            addAsset(_assets[i]);
        }
    }

    // getAsset returns asset
    function getAsset(uint256 id) public returns (Assets.Asset memory) {
        return assets.get(id);
    }
}
