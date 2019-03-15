pragma solidity >=0.4.21 <0.6.0;

library Polls {
    struct PollItem {
        bytes32 key;
        bytes data;
        bool active;
        bool executed;
        uint256 executedAt;
        address caller;
        uint256 threshold;
        uint256 totalVoters;
    }

    struct Poll {
        mapping (bytes32 => PollItem) polls;
    }

    function create(Poll storage polls, bytes32 key, bytes memory data, address caller) public {
        PollItem memory poll;
        poll.key = key;
        poll.data = data;
        poll.caller = caller;
        poll.active = true;

        polls.polls[key] = poll;
    }

    function execute(Poll storage polls, bytes32 key) public {
        polls.polls[key].active = false;
        polls.polls[key].executed = true;
        polls.polls[key].executedAt = now;

        bool result;
        bytes memory data;
        (result, data) = polls.polls[key].caller.call(polls.polls[key].data);

        if (!result) {
            revert("call failed");
        }
    }

    function isActive(Poll storage polls, bytes32 key) public returns (bool) {
        return polls.polls[key].active;
    }

    function isNotActive(Poll storage polls, bytes32 key) public returns (bool) {
        return polls.polls[key].active == false;
    }
}
