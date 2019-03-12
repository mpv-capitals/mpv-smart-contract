pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import "zos-lib/contracts/Initializable.sol";
import "./SafeMath.sol";

// NOTE: this is proof-of-concept quality
// and will be refactored heavily

contract MasterPropertyValue is Initializable {
  using SafeMath for uint256;

  // frozen is a flag to set freeze contract.
  bool public frozen;

  // mintingVoteThreshold is how many votes by minting admins
  // are required for asset to be enlisted.
  uint256 public mintingVoteThreshold;

  // redemptionVoteThreshold is how many votes by redemption admins
  // are required for asset to be redeemed by user.
  uint256 public redemptionVoteThreshold;

  // mintingCountdownLength is the time window that admins have to approve.
  uint256 public mintingCountdownLength;

  // redemptionCountdownLength is the time window that admins have to approve redemptionr requests.
  uint256 public redemptionCountdownLength;

  // mintingVotingInProgress is true when minting admins are voting for addition of assets.
  bool public mintingVotingInProgress;

  // mintingVotingEndDate is when voting for minting will end.
  uint256 public mintingVotingEndDate;

  // mintingAdminsCount is the total count of minting admins.
  uint256 public mintingAdminsCount;

  // redemptionVotingInProgress is true when redemption admins are voting for approving redemption of assets.
  mapping (uint256 => bool) public redemptionVotingInProgress;

  // redemptionVotingEndDate is when voting for asset redemption will end.
  mapping (uint256 => uint256) public redemptionVotingEndDate;

  // owners is a list of contract owners.
  // owners can add additional owners.
  // owners can remove other owners.
  mapping (address => bool) public owners;

  // operationAdmins is a list of operation admins.
  // operation admins can add users to whitelist or blacklist.
  // operation admins are manged by owners.
  mapping (address => bool) public operationAdmins;

  // mintingAdmins is a list of minting admins.
  // minting admins can add new token circulation.
  // minting admins are managed by owners.
  mapping (address => bool) public mintingAdmins;

  // redemptionAdmins is a list of redemption admins.
  // redemption admins approve redemptions.
  // redemption admins can burn tokens.
  mapping (address => bool) public redemptionAdmins;

  // whitelist is a list of whitelisted users allowed to receive and transfer token.
  mapping (address => bool) public whitelist;

  // blacklist is a list of blacklisted users not allowed to receive and transfer token.
  mapping (address => bool) public blacklist;

  // assets is a list of assets managed by this contract.
  mapping (uint256 => Asset) public assets;

  // pendingRedemptions is a list assets that are pending approval for redemption.
  mapping (uint256 => address) public pendingRedemptions;

  // pendingAssets is a list of asset IDs that are pending approval to be enlisted.
  uint256[] public pendingAssets;

  // mintingVotes are addresses of minting admins required for minting of asset.
  Vote[] public mintingVotes;

  // redemptionVotes is are votes for approval of an asset redemption.
  mapping (uint256 => Vote[]) public redemptionVotes;

  // State is the possible states for an asset.
  enum State {
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

  struct Vote {
    // address is address of voter.
    address voter;

    // voted is true if voter voted.
    bool voted;

    // value is vote casted.
    // 0 = no, 1 = yes.
    uint8 value;
  }

  // Asset is the structure for an asset.
  struct Asset {
    // id is asset ID.
    uint256 id;

    // state is current state asset is in.
    State state;

    // valuation is value of asset in USD.
    uint256 valuation;

    // fingerprint is the notarized certificate ID or hash.
    bytes32 fingerprint;

    // tokensRequired is how many tokens are required to redeem this asset.
    uint256 tokensRequired;

    // owner is the redeemer of the asset.
    address owner;
  }

  // LogPendingRedemption is the log event emitted when a user starts the redemption process for an asset.
  event LogPendingRedemption(uint256 assetId, address redeemer);

  // LogRedeemed is the log event emitted when an asset has been approved by the redemption admin
  // and the token has been transferred to the user.
  event LogRedeemed(uint256 assetId, address redeemer);

  // initialize is the constructor of the smart contract.
  function initialize() initializer public {
    owners[msg.sender] = true;

    mintingVoteThreshold = 66;
    redemptionVoteThreshold = 66;
    mintingCountdownLength = 48 hours;
    redemptionCountdownLength = 48 hours;
  }

  // constructor is the constructor of the smart contract.
  modifier isOwner() {
    require(owners[msg.sender] == true);
    _;
  }

  // isOperationAdmin requires that the caller is an operation admin.
  modifier isOperationAdmin() {
    require(operationAdmins[msg.sender] == true);
    _;
  }

  // isMintingAdmin requires that the caller is a minting admin.
  modifier isMintingAdmin() {
    require(mintingAdmins[msg.sender] == true);
    _;
  }

  // isRedemptionAdmin requires that the caller is a redemptionaAdmin.
  modifier isRedemptionAdmin() {
    require(redemptionAdmins[msg.sender] == true);
    _;
  }

  // votingStarted requires that voting for minting has begun.
  modifier votingStarted() {
    require(mintingVotingInProgress == true);
    require(now <= mintingVotingEndDate);
    _;
  }

  // votingNotStarted requires that voting for minting has not yet begun.
  modifier votingNotStarted() {
    require(mintingVotingInProgress == false);
    _;
  }

  // isUnfrozen requires that the contract be unfrozen.
  modifier isUnfrozen() {
    require(frozen == false);
    _;
  }

  // addOwner adds a new owner to the owners mapping by an existing owner.
  function addOwner(address user) public isOwner {
    require(owners[user] == false);
    owners[user] = true;
  }

  // removeOwner removes an existing owner from owners mapping by an existing owner.
  function removeOwner(address user) public isOwner {
    require(owners[user] == true);
    owners[user] = false;
  }

  // addOperationAdmin adds an operation admin to the operation admins mapping by an existing owner.
  function addOperationAdmin(address user) public isOwner {
    require(operationAdmins[user] == false);
    operationAdmins[user] = true;
  }

  // removeOperationAdmin removes an operation admin from the operation admins mapping by an existing owner.
  function removeOperationAdmin(address user) public isOwner {
    require(operationAdmins[user] == true);
    operationAdmins[user] = false;
  }

  // addMintingAdmin adds a minting admin to the minting admins mapping by an existing owner.
  // cannot add a new minting admin while voting is in progress.
  function addMintingAdmin(address user) public isOwner votingNotStarted {
    require(mintingAdmins[user] == false);
    mintingAdmins[user] = true;
    mintingAdminsCount++;
  }

  // removeMintingAdmin removes a minting admin from the minting admins mapping by an existing owner.
  // cannot remove a minting admin while voting is in progress.
  function removeMintingAdmin(address user) public isOwner votingNotStarted {
    require(mintingAdmins[user] == true);
    mintingAdmins[user] = false;
    mintingAdminsCount--;
  }

  // addRedemptionAdmin adds a redemption admin to the redemptions admins mapping by an existing owner.
  function addRedemptionAdmin(address user) public isOwner {
    require(redemptionAdmins[user] == false);
    redemptionAdmins[user] = true;
  }

  // removeMintingAdmin removes a redemption admin from the redemption admins mapping by an existing owner.
  function removeRedemptionAdmin(address user) public isOwner {
    require(redemptionAdmins[user] == true);
    redemptionAdmins[user] = false;
  }

  // whitelistRecipient adds a receipient of tokens to the whitelist by an operation admin.
  function whitelistRecipient(address recipient) public isOperationAdmin {
    whitelist[recipient] = true;
    blacklist[recipient] = false;
  }

  // blacklistRecipient adds a receipient of tokens to the blacklist by an operation admin.
  // the recipient will not be able to transfer tokens.
  function blacklistRecipient(address recipient) public isOperationAdmin {
    whitelist[recipient] = false;
    blacklist[recipient] = true;
  }

  // setMintingCountdownLength sets the countdown period length for voting on assets to be enlisted.
  // the countdown cannot be changed while voting is in progress.
  function setMintingCountdownLength(uint256 newCountdownLength) public isOwner votingNotStarted {
    require(mintingCountdownLength != newCountdownLength);
    mintingCountdownLength = newCountdownLength;
  }

  // setRedemptionCountdownLength sets the countdown period length for voting on assets redemption.
  function setCountdown(uint256 newCountdownLength) public isOwner {
    require(mintingCountdownLength != newCountdownLength);
    mintingCountdownLength = newCountdownLength;
  }

  // precheck checks whether it's allowed to add or remove new assets.
  function precheck() internal {
    if (mintingVotingInProgress) {
      if (mintingVoteThresholdReached()) {
        // cannot add new pending assets if vote threshold has been reached.
        revert("cannot add new assets when threshold has been met");
        return;
      }

      // minting admins are required to re-vote if threshold is not met and new assets are added.
      clearMintingVotes();
    } else {
      startVotingPeriod();
    }
  }

  // addAssets accepts a list of assets to be added by an owner.
  function addAssets(Asset[] memory _assets) public isOwner isUnfrozen {
    require(_assets.length > 0);
    precheck();

    for (uint256 i = 0; i < _assets.length; i++) {
      addAsset(_assets[i]);
    }
  }

  // removeAssets accepts a list of asset IDs to be removed by an owner.
  function removeAssets(uint256[] memory assetIds) public isOwner isUnfrozen {
    require(assetIds.length > 0);
    precheck();

    for (uint256 i = 0; i < assetIds.length; i++) {
      removeAsset(assetIds[i]);
    }
  }

  // addAsset adds an asset to the assets mapping mapping and pending list.
  function addAsset(Asset memory asset) public isOwner isUnfrozen {
      require(asset.id != 0);
      require(assets[asset.id].id == 0);
      precheck();

      asset.state = State.PENDING;
      assets[asset.id] = asset;
      pendingAssets.push(asset.id);
  }

  // removeAsset remove an asset to the assets mapping and pending list.
  function removeAsset(uint256 assetId) public isOwner isUnfrozen {
      require(assetId != 0);
      require(assets[assetId].id != 0);
      precheck();

      delete assets[assetId];

      for (uint256 i = 0; i < pendingAssets.length; i++) {
        if (pendingAssets[i] == assetId) {
          delete pendingAssets[i];
          pendingAssets.length--;
          break;
        }
      }
  }

  // startVotingPeriod starts the voting period.
  // an admin may call this method to restart voting if
  // previously had cancelled voting.
  function startVotingPeriod() public isOwner votingNotStarted isUnfrozen {
    require(pendingAssets.length > 0);
    mintingVotingInProgress = true;
    mintingVotingEndDate = now + mintingCountdownLength;
  }

  // endVotingPeriod ends the voting period.
  function endVotingPeriod() internal isOwner {
    mintingVotingInProgress = false;
    mintingVotingEndDate = 0;
    clearMintingVotes();
  }

  // update refreshes the state of the smart contract.
  // anyone can call this method.
  function update() public {
    // voting period has ended
    if (mintingVotingInProgress && now > mintingVotingEndDate) {
      endVotingPeriod();

      // require minting votes to enlist assets
      if (mintingVotes.length > 0) {
        // if vote threshold reached then enlist assets and mint tokens
        if (mintingVoteThresholdReached()) {
          enlistPendingAssets();
          mintTokens();
        }
      }
    }
  }

  // mintingVoteThresholdReached returns true if vote threshold is met.
  function mintingVoteThresholdReached() internal returns (bool) {
    uint256 yesVotes = 0;
    for (uint256 i = 0; i < mintingVotes.length; i++) {
      if (mintingVotes[i].value == 1) {
        yesVotes++;
      }
    }

    return (yesVotes.div(mintingAdminsCount)).mul(100) >= mintingVoteThreshold;
  }

  // redemptionVoteThresholdReached returns true if vote threshold is met for asset.
  function redemptionVoteThresholdReached(uint256 assetId) internal returns (bool) {
    uint256 yesVotes = 0;
    Vote[] memory votes = redemptionVotes[assetId];
    for (uint256 i = 0; i < votes.length; i++) {
      if (votes[i].value == 1) {
        yesVotes++;
      }
    }

    return (yesVotes.div(votes.length)).mul(100) >= redemptionVoteThreshold;
  }

  // enlistPendingAssets changes the status of pending assets to enlisted.
  function enlistPendingAssets() internal votingNotStarted {
    for (uint256 i = 0; i < pendingAssets.length; i++) {
      assets[pendingAssets[i]].state = State.ENLISTED;
    }

    delete pendingAssets;
  }

  // cancelAssetMinting allows an owner to cancel the asset minting process.
  function cancelAssetMinting() public isOwner votingStarted {
    endVotingPeriod();
    clearMintingVotes();
  }

  // clearMintingVotes clears all minting votes.
  function clearMintingVotes() internal {
    delete mintingVotes;
  }

  // submitMintingVote allows minting admins to vote for minting.
  function submitMintingVote(uint256 assetId, uint8 vote) public isMintingAdmin votingStarted {
    Asset memory asset = assets[assetId];
    // TODO: use enum
    require(vote == 0 || vote == 1);

    bool updated = false;
    uint256 index = 0;
    // be able to update vote if already submitted
    for (index = 0; index < mintingVotes.length; index++) {
      if (mintingVotes[index].voter == msg.sender) {
        mintingVotes[index].value = vote;
        updated = true;
      }
    }

    // submit a new vote if not submitted previously
    if (updated == false) {
      Vote memory v;
      v.voter = msg.sender;
      v.voted = true;
      v.value = vote;
      mintingVotes.push(v);
    }

    update();
  }

  // mintTokens allows minting admin to mint new tokens when asset is created.
  function mintTokens() public isMintingAdmin isUnfrozen {
    // TODO: use token contract
  }

  // burnTokens allows minting admin to burn tokens when asset is redeemed.
  function burnTokens() public isRedemptionAdmin isUnfrozen {
    // TODO: use token contract
  }

  // transfer allows transfer of tokens.
  function transfer() public isUnfrozen {
    require(blacklist[msg.sender] == false);
  }

  // transfer allows transfer of tokens.
  function transferToken() public {
    require(whitelist[msg.sender] == true);
    require(blacklist[msg.sender] == false);
  }

  // transfer allows user to start redemption process for asset.
  function redeem(uint256 assetId) public isUnfrozen {
    Asset memory asset = assets[assetId];
    require(asset.state == State.ENLISTED);
    require(whitelist[msg.sender] == true);
    require(blacklist[msg.sender] == false);
    //require(userTokens >= asset.tokensRequired)
    // TODO: user must 'allow' contract to transer tokens
    // TODO: lock user tokens

    pendingRedemptions[assetId] = msg.sender;
    emit LogPendingRedemption(assetId, msg.sender);
  }

  // submitRedemptionVote allows a redemption admin to submit a vote to determine if asset should be redeemable by user.
  function submitRedemptionVote(uint256 assetId, uint8 vote) public isRedemptionAdmin isUnfrozen {
    Asset memory asset = assets[assetId];
    require(asset.state == State.LOCKED);
    require(vote == 0 || vote == 1);

    // only takes 1 rejection vote to reject redemption
    if (vote == 0) {
      rejectRedemption(assetId);
    }

    bool updated = false;
    uint256 index = 0;

    // be able to update vote if already submitted
    for (index = 0; index < redemptionVotes[assetId].length; index++) {
      if (redemptionVotes[assetId][index].voter == msg.sender) {
        redemptionVotes[assetId][index].value = vote;
        updated = true;
      }
    }

    // submit a new vote if not submitted previously
    if (updated == false) {
      Vote memory v;
      v.voter = msg.sender;
      v.voted = true;
      v.value = vote;
      redemptionVotes[assetId].push(v);
    }

    refreshRedemptionStatus(assetId);
  }

  // refreshRedemptionStatus refresh redemption state for an asset.
  function refreshRedemptionStatus(uint256 assetId) public {
    if (redemptionVotingInProgress[assetId]) {
      if (redemptionVoteThresholdReached(assetId)) {
        // TODO: start countdown f
        approveRedemption(assetId);
        return;
      }
    }

    // TODO
  }

  // approveRedemption allows redemption admin to approve redemption of asset.
  function approveRedemption(uint256 assetId) internal isUnfrozen {
    Asset memory asset = assets[assetId];
    require(asset.state == State.LOCKED);
    asset.state = State.REDEEMED;
    address redeemer = pendingRedemptions[assetId];
    require(redeemer != address(0));
    // burn tokens of user
    burnTokens();
    asset.owner = redeemer;
    delete pendingRedemptions[assetId];
    redemptionVotingInProgress[assetId] = false;
    emit LogRedeemed(assetId, redeemer);
  }

  // approveRedemption allows owner to reject redemption of asset.
  function rejectRedemption(uint256 assetId) public isOwner isUnfrozen {
    Asset memory asset = assets[assetId];
    require(asset.state == State.LOCKED);
    asset.state = State.ENLISTED;
    asset.owner = address(0);
    // TODO: unlock user tokens
  }

  // approveRedemption allows user to cancel redemption of asset.
  function cancelRedemption(uint256 assetId) public isUnfrozen {
    Asset memory asset = assets[assetId];
    require(asset.state == State.LOCKED);
    require(asset.owner == msg.sender);
    asset.state = State.ENLISTED;
    asset.owner = address(0);
    // TODO: unlock user tokens
  }

  // freeze allows a contract owner to freeze the contract.
  // freezing the contract will:
  // - stop any token transfer
  // - remove all countdowns
  // - prevent redemption
  function freeze() public isOwner {
    require(frozen == false);
    frozen = true;
    endVotingPeriod();
    clearMintingVotes();
  }

  // unfreeze allows a contract owner to unfreeze the contract.
  function unfreeze() public isOwner {
    require(frozen == true);
    frozen = false;
  }
}
