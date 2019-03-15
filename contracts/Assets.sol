pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./Roles.sol";

library Assets {
  // Asset is the structure for an asset.
  struct Asset {
    // id is asset ID.
    uint256 id;

    // status is current state asset is in.
    Status status;

    // valuation is value of asset in USD.
    uint256 valuation;

    // fingerprint is the notarized certificate ID or hash.
    bytes32 fingerprint;

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

  // State is library state.
  struct State {
    mapping (uint256 => Asset) assets;
  }

  function add(State storage data, Asset memory asset) public {
    require(data.assets[asset.id].id == 0);
    data.assets[asset.id] = asset;
  }

  function get(State storage data, uint256 id) public returns (Asset memory) {
    return data.assets[id];
  }

  // addList accepts a list of assets to be added by an owner.
  function addList(State storage data, Asset[] memory assets) public {
    require(assets.length > 0);

    for (uint256 i = 0; i < assets.length; i++) {
      add(data, assets[i]);
    }
  }
}

