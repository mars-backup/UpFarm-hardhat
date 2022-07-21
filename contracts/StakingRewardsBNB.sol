// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./StakingRewards.sol";
import "./libs/TransferHelper.sol";

contract StakingRewardsBNB is StakingRewards {
    using SafeMath for uint256;

    constructor(
        address _core,
        address _upToken,
        address _WBNB,
        address _vestingMaster,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public
        StakingRewards(
            _core,
            _upToken,
            _WBNB,
            _vestingMaster,
            _tokenPerBlock,
            _startBlock,
            _endBlock
        )
    {}

    receive() external payable {}

    function safeTokenTransfer(address _to, uint256 _amount)
        internal
        override
        returns (uint256)
    {
        uint256 balance = address(this).balance;
        uint256 amount = _amount > balance ? balance : _amount;
        if (amount > 0) {
            TransferHelper.safeTransferETH(_to, amount);
        }
        return amount;
    }
}