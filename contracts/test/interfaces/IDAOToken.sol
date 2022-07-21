// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IDAOToken {
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    // ----------- Events -----------

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    // ----------- State changing api -----------

    function delegates(address delegator) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // ----------- Getters -----------

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        returns (uint256);
}